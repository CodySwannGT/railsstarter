# frozen_string_literal: true

require 'capybara/rspec'
require_relative '../fixtures/browser/request_security_harness'

Capybara.threadsafe = true

RSpec.describe RequestSecurity do
  context 'with real Chrome' do
    let(:harness) { described_class.new }
    let(:page) { harness.page }

    around do |example|
      harness.start
      example.run
    ensure
      begin
        harness.capture('failure') if example.exception && harness.page
      ensure
        harness.stop
      end
    end

    def wait_for(&)
      Selenium::WebDriver::Wait.new(timeout: 10).until(&)
    end

    def initialized
      wait_for { page.evaluate_script('!!window.Stimulus && !!window.Turbo') }
    end

    def expect_fresh_nonces
      first, second = Array.new(2) { harness.response('/') }
      expect_enforced_policy(first)
      nonce = first[:csp].match(/'nonce-([^']+)'/)[1]
      expect(first[:body]).to include("name=\"csp-nonce\" content=\"#{nonce}\"", "nonce=\"#{nonce}\"")
      expect(second[:csp].match(/'nonce-([^']+)'/)[1]).not_to eq(nonce)
    end

    def expect_enforced_policy(first)
      expect(first[:status]).to eq(200)
      expect(first[:csp]).to include("default-src 'self'", "object-src 'none'", "frame-ancestors 'none'")
      expect(first[:csp]).not_to match(/unsafe-inline|unsafe-eval|\*|(?:^|\s)https:(?:\s|;)/)
    end

    def expect_loaded_resources
      expect(page.evaluate_script('!!document.querySelector("link[href*=bootstrap]").sheet')).to be(true)
      expect(page.evaluate_script('getComputedStyle(document.querySelector("nav")).display')).to eq('flex')
      expect(page.evaluate_script('bootstrap.Collapse.VERSION')).to eq('5.3.8')
      match_nonces = <<~JS
        Array.from(document.querySelectorAll('script[type=importmap],script[type=module]:not([src])'))
          .every(s => s.nonce === document.querySelector('meta[name=csp-nonce]').content)
      JS
      expect(page.evaluate_script(match_nonces)).to be(true)
    end

    def expect_navigation_and_flash
      page.find('button[aria-label="Toggle navigation"]').click
      expect(page).to have_css('#navbar-navigation.show', visible: :visible)
      page.find('button[aria-label="Close"]').click
      expect(page).to have_no_css('#flash-messages .alert', visible: :all)
      expect_turbo_navigation
    end

    def expect_turbo_navigation
      page.execute_script('window.requestSecurityDocumentIdentity = "same-document"; Turbo.setProgressBarDelay(0)')
      page.find('#navbar-navigation a', text: 'Home').click
      expect(page).to have_current_path('/')
      initialized
      expect(page.evaluate_script('window.requestSecurityDocumentIdentity')).to eq('same-document')
    end

    it('enforces request nonces while scripts, styles, navbar, flash and Turbo navigation work') do
      expect_fresh_nonces
      page.visit('/__request_security')
      initialized
      expect_loaded_resources
      expect_navigation_and_flash
      expect(harness.violations).to eq([])
      expect(harness.errors).to eq([])
      harness.capture('positive')
    end

    def inject_untrusted_content
      page.execute_script(<<~JS, harness.other_origin)
        const inline = document.createElement('script'); inline.textContent = 'window.inlineRan = true'; document.body.append(inline);
        const style = document.createElement('style'); style.textContent = 'body { --unauthorized-inline: reached }'; document.head.append(style);
        const wrong = document.createElement('script'); wrong.nonce = 'unacceptednonce'; wrong.textContent = 'window.wrongNonceRan = true'; document.body.append(wrong);
        const bad = document.createElement('script'); bad.src = arguments[0] + '/__unauthorized.js'; document.body.append(bad);
        const css = document.createElement('link'); css.rel = 'stylesheet'; css.href = arguments[0] + '/__unauthorized.css'; document.head.append(css);
        const button = document.createElement('button'); button.setAttribute('onclick','window.handlerRan = true'); document.body.append(button); button.click();
      JS
    end

    it('blocks absent nonces, inline handlers and an unlisted script and style origin') do
      page.visit('/__request_security')
      initialized
      expect(harness.response('/__unauthorized.js')[:status]).to eq(200)
      inject_untrusted_content
      wait_for { harness.violations.length >= 5 }
      expect(page.evaluate_script('!!window.inlineRan || !!window.unauthorizedSourceRan || !!window.handlerRan || !!window.wrongNonceRan')).to be(false)
      expect(page.evaluate_script('["--unauthorized-inline", "--unauthorized-source"].map(p => getComputedStyle(document.body).getPropertyValue(p))')).to eq(['', ''])
      expect(harness.violations.map { |event| event.fetch('directive') }).to include('script-src-elem', 'style-src-elem', 'script-src-attr')
      expect(harness.violations.all? { |event| event['disposition'] == 'enforce' }).to be(true)
      harness.capture('unauthorized-controls')
    end

    it('detects missing importmap nonce and required CDN source controls in real Chrome') do
      page.visit('/__request_security?control=nonce')
      wait_for { harness.violations.any? { |event| event['directive'] == 'script-src-elem' } }
      expect(page.evaluate_script('!!window.Stimulus || !!window.Turbo')).to be(false)
      harness.capture('nonce-control')
      page.visit('/__request_security?control=cdn')
      initialized
      wait_for { harness.violations.length >= 2 }
      harness.capture('required-source-observation')
      expect(page.evaluate_script('getComputedStyle(document.querySelector("nav")).display')).to eq('block')
      expect(page.evaluate_script('!!window.bootstrap')).to be(false)
      harness.capture('required-source-control')
    end
  end

  context 'with harness prerequisites and teardown' do
    def browser_inventory_fixture
      birth = 'Wed Oct 7 03:52:44 2026'
      details = {
        100 => { pid: 100, ppid: Process.pid, pgid: 100, uid: Process.uid, birth: birth },
        101 => { pid: 101, ppid: 100, pgid: 100, uid: Process.uid, birth: birth },
        102 => { pid: 102, ppid: 101, pgid: 100, uid: Process.uid, birth: birth }
      }
      anchors = details.slice(100, 101)
      rows = ["101 100 #{birth}", "102 101 #{birth}"]
      [anchors, rows, details]
    end

    it('refuses a matching-profile child whose ancestry belongs to another owner') do
      anchors, rows, details = browser_inventory_fixture
      details[102][:ppid] = Process.pid
      rows[1] = "102 #{Process.pid} #{details[102][:birth]}"
      expect { RequestSecurityBrowserInventory.new(anchors, rows).validate(details) }.to raise_error(/ancestry/)
    end

    it('refuses a reused captured root and a changed driver before child admission') do
      anchors, rows, details = browser_inventory_fixture
      anchors = Marshal.load(Marshal.dump(anchors))
      details[101][:birth] = 'Wed Oct 7 03:52:45 2026'
      expect { RequestSecurityBrowserInventory.new(anchors, rows).validate(details) }.to raise_error(/anchor identity/)
      details[101][:birth] = anchors[101][:birth]
      details[100][:ppid] = 1
      expect { RequestSecurityBrowserInventory.new(anchors, rows).validate(details) }.to raise_error(/anchor identity/)
    end

    it('refuses missing metadata and malformed or duplicate profile identities') do
      anchors, rows, details = browser_inventory_fixture
      expect { RequestSecurityBrowserInventory.new(anchors, rows).validate(details.except(102)) }.to raise_error(/identity/)
      expect { RequestSecurityBrowserInventory.new(anchors, [rows.first, 'malformed']).validate(details) }.to raise_error(/profile/)
      expect { RequestSecurityBrowserInventory.new(anchors, rows + [rows.last]).validate(details) }.to raise_error(/profile/)
      expect { RequestSecurityBrowserInventory.new(anchors, [rows.last]).validate(details) }.to raise_error(/root profile/)
    end

    it('refuses a live foreign process copying the exact owned Chrome profile') do
      harness = described_class.new
      harness.start
      profile = File.join(harness.instance_variable_get(:@scratch), 'chrome')
      with_term_ignoring_child("--user-data-dir=#{profile}") do |child|
        expect { harness.send(:captured_chrome_processes) }.to raise_error(/ancestry|owner/)
        expect(child.signals).to eq([])
        expect(child.absent?).to be(false)
      end
    ensure
      harness&.stop
    end

    it('refuses foreign UID and process group even when profile and parent match') do
      anchors, rows, details = browser_inventory_fixture
      details[102][:uid] += 1
      expect { RequestSecurityBrowserInventory.new(anchors, rows).validate(details) }.to raise_error(/owner/)
      details[102][:uid] = Process.uid
      details[102][:pgid] += 1
      expect { RequestSecurityBrowserInventory.new(anchors, rows).validate(details) }.to raise_error(/owner/)
    end

    def replacement_browser_anchors(actual)
      driver = actual.merge(pid: Process.ppid, ppid: 0)
      root = actual.merge(pid: actual[:ppid], ppid: Process.ppid)
      { driver[:pid] => driver, root[:pid] => root }
    end

    def replacement_browser_inventory(harness, actual)
      anchors = replacement_browser_anchors(actual)
      replacement = actual.merge(birth: (Time.strptime(actual[:birth], '%a %b %e %H:%M:%S %Y') + 1).strftime('%a %b %-d %H:%M:%S %Y'))
      details = anchors.merge(actual[:pid] => replacement)
      rows = [anchors.fetch(actual[:ppid]), replacement].map { |row| "#{row[:pid]} #{row[:ppid]} #{row[:birth]}" }
      harness.instance_variable_set(:@browser_anchors, anchors)
      allow(harness).to receive(:owned_browser_processes).and_return(rows)
      allow(RequestSecurityObservation).to receive(:metadata).and_return(details)
    end

    it('refuses a coherent replacement birth after a late child was captured') do
      harness = described_class.new
      with_term_ignoring_child do |child|
        actual = RequestSecurityObservation.metadata([child.pid]).fetch(child.pid)
        captured = harness.send(:capture_later_browser, child.pid, actual)
        replacement_browser_inventory(harness, actual)
        expect(captured.instance_variable_get(:@owner_check).call).to be(false)
        expect(captured.signals).to eq([])
        expect(child.absent?).to be(false)
      end
    end

    def executable(directory, name, mode = 0o700)
      path = File.join(directory, name)
      File.write(path, '#!/bin/sh\nexit 0\n', mode: 'wx', perm: mode)
      path
    end

    def in_owned_directory(&)
      Dir.mktmpdir('request-security-prerequisite-', &)
    end

    it('discovers hosted Linux Chrome and driver executables on PATH') do
      in_owned_directory do |directory|
        chrome = executable(directory, 'google-chrome')
        driver = executable(directory, 'chromedriver')
        expect(RequestSecurityExecutable.chrome({ 'PATH' => directory }, 'x86_64-linux')).to eq(chrome)
        expect(RequestSecurityExecutable.driver({ 'PATH' => directory })).to eq(driver)
      end
    end

    it('uses a verified public macOS Chrome override including spaces') do
      in_owned_directory do |directory|
        chrome = executable(directory, 'Google Chrome')
        expect(RequestSecurityExecutable.chrome({ 'CHROME_BIN' => chrome }, 'arm64-darwin')).to eq(chrome)
      end
    end

    it('names missing Chrome instead of silently selecting another executable') do
      in_owned_directory do |directory|
        executable(directory, 'google-chrome')
        environment = { 'CHROME_BIN' => File.join(directory, 'missing'), 'PATH' => directory }
        expect { RequestSecurityExecutable.chrome(environment, 'x86_64-linux') }.to raise_error(/CHROME_BIN.*executable/)
      end
    end

    it('refuses a directory and a nonexecutable driver with clear prerequisite errors') do
      in_owned_directory do |directory|
        driver = executable(directory, 'chromedriver', 0o600)
        expect { RequestSecurityExecutable.chrome({ 'CHROME_BIN' => directory }) }.to raise_error(/CHROME_BIN.*executable/)
        expect { RequestSecurityExecutable.driver({ 'CHROMEDRIVER' => driver }) }.to raise_error(/CHROMEDRIVER.*executable/)
      end
    end

    it('names an absent Linux browser prerequisite with no macOS fallback') do
      expect { RequestSecurityExecutable.chrome({ 'PATH' => '' }, 'x86_64-linux') }.to raise_error(/Chrome executable.*CHROME_BIN/)
    end

    def with_term_ignoring_child(*)
      process_class = RequestSecurityProcess
      reader, writer = IO.pipe
      pid = Process.spawn(RbConfig.ruby, '-e', 'trap("TERM") {}; STDOUT.puts("ready"); STDOUT.flush; sleep 60', '--', *,
                          pgroup: true, out: writer, err: File::NULL)
      child = process_class.new(pid, child: true)
      writer.close
      raise 'Owned timeout child not ready' unless reader.wait_readable(5) && reader.gets == "ready\n"

      yield child
    ensure
      reader&.close
      writer&.close
      child&.terminate(timeout: 0.1)
      persist_child_readback(child) if child
    end

    def persist_child_readback(child)
      directory = ENV.fetch('REQUEST_SECURITY_ARTIFACT_DIR', nil)
      return unless directory

      record = { pid: child.pid, identity: child.identity, signals: child.signals, reaped: child.reaped, absent: child.absent? }
      path = File.join(directory, "timeout-child-#{child.pid}-#{SecureRandom.hex(4)}.json")
      File.write(path, JSON.pretty_generate(record), mode: 'wx', perm: 0o600)
    end

    it('bounds TERM refusal, escalates only its captured child and proves reaping and absence') do
      with_term_ignoring_child do |child|
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        child.terminate(timeout: 0.1)
        expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 2
        expect(child.signals).to eq(%w[TERM KILL])
        expect(child.reaped).to be(true)
        expect(child.absent?).to be(true)
      end
    end

    it('refuses stale start identity without signalling or reaping the live child') do
      with_term_ignoring_child do |child|
        impostor = RequestSecurityProcess.new(child.pid, child: true)
        impostor.instance_variable_set(:@identity, 'stale start identity')
        expect { impostor.terminate(timeout: 0.1) }.to raise_error(/identity changed/)
        expect(impostor.signals).to eq([])
        expect(child.absent?).to be(false)
      end
    end

    it('refuses lost profile ownership before signalling an otherwise matching PID') do
      with_term_ignoring_child do |child|
        impostor = RequestSecurityProcess.new(child.pid, child: true, owner_check: -> { false })
        expect { impostor.terminate(timeout: 0.1) }.to raise_error(/profile ownership changed/)
        expect(impostor.signals).to eq([])
        expect(child.absent?).to be(false)
      end
    end

    it('accepts positively reaped exit during profile validation without sending another signal') do
      with_term_ignoring_child do |child|
        owner_check = lambda do
          child.terminate(timeout: 0.1)
          false
        end
        controller = RequestSecurityProcess.new(child.pid, child: true, owner_check: owner_check)

        expect { controller.request_termination }.not_to raise_error
        expect(controller.signals).to eq([])
        expect(child.reaped).to be(true)
        expect(child.absent?).to be(true)
      end
    end

    it('rechecks profile ownership before KILL after TERM refusal') do
      with_term_ignoring_child do |child|
        checks = 0
        owner_check = lambda do
          checks += 1
          checks == 1
        end
        controller = RequestSecurityProcess.new(child.pid, child: true, owner_check: owner_check)
        expect { controller.terminate(timeout: 0.1) }.to raise_error(/profile ownership changed/)
        expect(controller.signals).to eq(['TERM'])
        expect(child.absent?).to be(false)
      end
    end

    it('refuses a process that is not its direct child before permitting reap') do
      expect { RequestSecurityProcess.new(Process.pid, child: true) }.to raise_error(/not our direct child/)
    end

    it('matches only the exact owned profile flag and leaves a prefix neighbor untouched') do
      harness = described_class.new
      harness.setup_scratch
      profile = File.join(harness.instance_variable_get(:@scratch), 'chrome')
      with_term_ignoring_child("--user-data-dir=#{profile}-neighbor") do |child|
        expect(harness.send(:owned_browser_processes)).to eq([])
        expect(child.signals).to eq([])
        expect(child.absent?).to be(false)
      end
    ensure
      harness&.stop
    end

    it('refuses scratch deletion while the owned port is still listening') do
      harness = described_class.new
      harness.setup_scratch
      listener = TCPServer.new('127.0.0.1', harness.instance_variable_get(:@ports).first)
      expect { harness.send(:cleanup) }.to raise_error(/port still open/)
      expect(File.directory?(harness.instance_variable_get(:@scratch))).to be(true)
    ensure
      listener&.close
      harness&.stop
    end

    it('refuses scratch deletion when its recorded owner token no longer matches') do
      harness = described_class.new
      harness.setup_scratch
      owner_file = File.join(harness.instance_variable_get(:@scratch), 'owner.json')
      original = File.read(owner_file)
      File.write(owner_file, JSON.generate(token: 'different-owner'))
      expect { harness.send(:cleanup) }.to raise_error(/unowned browser scratch/)
      expect(File.directory?(harness.instance_variable_get(:@scratch))).to be(true)
    ensure
      File.write(owner_file, original) if original
      harness&.stop
    end

    it('bounds a hung quit, records the failure and reports actual scratch cleanup') do
      harness = described_class.new(cleanup_timeout: 0.1)
      harness.setup_scratch
      driver = instance_double(Capybara::Selenium::Driver)
      allow(driver).to receive(:quit) { sleep 60 }
      harness.instance_variable_set(:@page, instance_double(Capybara::Session, driver: driver))
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect { harness.stop }.to raise_error(/driver_quit.*timed out/)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 2
      expect(harness.cleanup_record).to include(scratch_removed: true, quit_thread_absent: true)
      expect(harness.cleanup_record[:errors]).to include(a_string_matching(/driver_quit.*timed out/))
    end

    def suspend_owned_browser(harness)
      harness.start
      harness.page.visit('/__request_security?control=nonce')
      Selenium::WebDriver::Wait.new(timeout: 10).until { harness.violations.any? }
      harness.send(:record_browser_ownership)
      driver_pid = harness.instance_variable_get(:@driver_pid)
      chrome = harness.instance_variable_get(:@chrome_processes).find { |process| process.identity.split[1] == driver_pid }
      raise 'Native shutdown fixture has no captured browser root' unless chrome

      chrome.send(:signal, 'STOP')
      resume = Thread.new do
        chrome.send(:signal, 'CONT') if RequestSecurityDeadline.wait(15) { chrome.signals.include?('TERM') }
      end
      [chrome, resume]
    end

    it('coordinates owned TERM with native ChromeDriver reaping before the quit deadline') do
      harness = described_class.new
      chrome, resume = suspend_owned_browser(harness)

      expect { harness.stop }.not_to raise_error
      expect(resume.join(1)).to be(resume)
      expect(harness.cleanup_record).to include(scratch_removed: true, driver_absent_after_quit: true,
                                                server_absent: true, quit_thread_absent: true, errors: [])
      expect(chrome.signals).to eq(%w[STOP TERM CONT])
      expect(chrome.absent?).to be(true)
    ensure
      harness&.stop unless harness&.cleanup_record
      resume&.kill
      resume&.join(1)
    end

    def later_cross_site_child(harness)
      harness.start
      harness.page.visit('/up')
      harness.send(:record_browser_ownership)
      captured, root = captured_browser_root(harness)
      browser = harness.page.driver.browser
      browser.switch_to.new_window(:tab)
      browser.navigate.to("#{harness.origin.sub('127.0.0.1', 'localhost')}/up")
      Selenium::WebDriver::Wait.new(timeout: 10).until { browser.execute_script('return location.hostname === "localhost" && document.readyState === "complete"') }
      verify_later_children(harness, captured, root)
      root
    end

    def captured_browser_root(harness)
      captured = harness.instance_variable_get(:@chrome_processes)
      driver_pid = harness.instance_variable_get(:@driver_pid)
      root = captured.find { |process| process.identity.split[1] == driver_pid }
      raise 'Cross-site fixture has no captured root' unless root

      [captured, root]
    end

    def verify_later_children(harness, captured, root)
      rows = harness.send(:owned_browser_processes)
      later = rows.reject { |row| captured.map(&:pid).include?(row.split.first.to_i) }
      raise 'No genuine later Chrome child observed' if later.empty?
      raise 'Captured root changed before suspension' unless RequestSecurityObservation.identity(root.pid.to_s).split == root.identity.split

      later.each { |row| verify_later_identity(row, root) }
    end

    def verify_later_identity(row, root)
      fields = row.split
      identity = RequestSecurityObservation.identity(fields.first).split
      raise 'Later Chrome ancestry identity disagrees' unless identity.values_at(0, 1, 3, 4, 5, 6, 7) == fields && fields[1] == root.pid.to_s
      raise 'Later Chrome process group disagrees' unless identity[2] == root.identity.split[2]
    end

    def finish_cross_site_fixture(harness, chrome, resume)
      resume&.kill
      resume&.join(1)
      chrome.send(:signal, 'CONT') if chrome&.signals&.include?('STOP') && chrome.signals.none?('CONT')
      harness&.stop unless harness&.cleanup_record&.dig(:scratch_removed)
    end

    it('cleans a verified later cross-site Chrome child while its captured root is suspended') do
      harness = described_class.new
      chrome = later_cross_site_child(harness)
      chrome.send(:signal, 'STOP')
      resume = Thread.new do
        chrome.send(:signal, 'CONT') if RequestSecurityDeadline.wait(15) { chrome.signals.include?('TERM') }
      end

      expect { harness.stop }.not_to raise_error
      expect(resume.join(1)).to be(resume)
      expect(chrome.signals).to eq(%w[STOP TERM CONT])
      expect(harness.cleanup_record).to include(scratch_removed: true, driver_absent_after_quit: true,
                                                server_absent: true, quit_thread_absent: true, errors: [])
    ensure
      finish_cross_site_fixture(harness, chrome, resume)
    end
  end
end
