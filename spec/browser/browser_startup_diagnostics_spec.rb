# frozen_string_literal: true

require 'spec_helper'
require_relative '../fixtures/browser/request_security_harness'
require_relative '../fixtures/browser/bootstrap_harness'

RSpec.describe BrowserStartupDiagnostics do
  let(:directory) { Dir.mktmpdir('browser-diagnostics-spec-') }
  let(:services) { [] }
  let(:original_error) { Selenium::WebDriver::Error::SessionNotCreatedError.new('fixture startup refusal') }
  let(:config) { instance_double(Capybara::SessionConfig) }
  let(:driver) { instance_double(Capybara::Selenium::Driver) }
  let(:session) { instance_double(Capybara::Session, config: config, driver: driver) }

  around do |example|
    previous = ENV.fetch('BROWSER_STARTUP_ARTIFACT_DIR', nil)
    ENV['BROWSER_STARTUP_ARTIFACT_DIR'] = File.join(directory, 'retained')
    example.run
  ensure
    ENV['BROWSER_STARTUP_ARTIFACT_DIR'] = previous
    FileUtils.remove_entry_secure(directory)
  end

  before do
    allow(config).to receive(:default_max_wait_time=)
    allow(config).to receive(:app_host=)
    allow(Capybara::Session).to receive(:new).and_return(session)
    allow(driver).to receive(:browser) do
      services.last.log&.write("[123:ERROR:startup.cc:1] fixture native startup refusal\n")
      raise original_error
    end
    allow(BrowserFixtureChromeService).to receive(:new).and_wrap_original do |original, **options|
      services << original.call(**options)
      services.last
    end
  end

  def prepared_fixture(type)
    fixture = type.new
    scratch = File.join(directory, type.name)
    Dir.mkdir(scratch, 0o700)
    fixture.instance_variable_set(:@scratch, scratch)
    fixture.instance_variable_set(:@token, SecureRandom.hex(16))
    fixture.instance_variable_set(:@origin, 'http://127.0.0.1:1')
    fixture.instance_variable_set(:@port, 1)
    fixture.instance_variable_set(:@driver_binary, '/fixture/chromedriver')
    fixture.instance_variable_set(:@chrome_binary, '/fixture/chrome')
    fixture
  end

  def native_driver_fixture
    path = File.join(directory, 'driver-fixture')
    File.write(path, "#!#{RbConfig.ruby}\n" + native_driver_source, mode: 'wx', perm: 0o700)
    path
  end

  def native_driver_source
    <<~'RUBY'
      require 'socket'
      require 'json'
      puts JSON.generate(ENV.to_h.slice('TMPDIR', 'TMP', 'TEMP'))
      $stdout.flush
      port = Integer(ARGV.grep(/^--port=/).first.split('=').last)
      server = TCPServer.new('127.0.0.1', port)
      loop do
        socket = server.accept
        request = socket.gets
        while (header = socket.gets) && header != "\r\n"
        end
        body = '{"value":{"ready":true}}'
        socket.write("HTTP/1.1 200 OK\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
        socket.close
        break if request.include?('/shutdown')
      end
      server.close
    RUBY
  end

  [RequestSecurity, BootstrapAssets].each do |type|
    context "with #{type.name}" do
      it('keeps the owned Chrome singleton socket within the Linux path limit') do
        fixture = type.new
        fixture.__send__(:setup_scratch)
        scratch = fixture.instance_variable_get(:@scratch)
        linux_parent = "/tmp/lisa-rails-scratch/r.#{'a' * 24}/tmp"
        socket_path = File.join(linux_parent, File.basename(scratch), 'com.google.Chrome.abcdef', 'SingletonSocket')
        expect(socket_path.bytesize).to be <= 107
        expect(File.stat(scratch).mode & 0o777).to eq(0o700)
        expect(JSON.parse(File.read(File.join(scratch, 'owner.json')))).to include('token' => fixture.instance_variable_get(:@token))
      ensure
        FileUtils.remove_entry_secure(scratch) if scratch && File.directory?(scratch)
      end

      it('retains startup failure diagnostics through a private verbose IO without replacing the exception') do
        fixture = prepared_fixture(type)
        expect { fixture.__send__(:start_browser) }.to raise_error(original_error) { |caught| expect(caught).to equal(original_error) }
        expect(services.last.args).to include('--verbose')
        records = Dir.glob(File.join(ENV.fetch('BROWSER_STARTUP_ARTIFACT_DIR'), '*', 'startup.json'))
        expect(records.length).to eq(1)
        expect(JSON.parse(File.read(records.first))).to include('error_class' => original_error.class.name)
      end
    end
  end

  context 'with owned diagnostic files' do
    let(:diagnostics) { described_class.new(directory, 'fixture') }

    it('gives the native driver owned temporary paths without changing the parent environment') do
      previous = ENV.to_h.slice('TMPDIR', 'TMP', 'TEMP')
      service = diagnostics.service(native_driver_fixture)
      manager = service.launch
      manager.stop
      service.log.rewind
      expect(JSON.parse(service.log.gets)).to eq('TMPDIR' => directory, 'TMP' => directory, 'TEMP' => directory)
      expect(ENV.to_h.slice('TMPDIR', 'TMP', 'TEMP')).to eq(previous)
    ensure
      manager&.stop
      diagnostics.close
    end

    it('retains an empty startup log when failure precedes driver execution') do
      diagnostics.retain(original_error)
      records = Dir.glob(File.join(ENV.fetch('BROWSER_STARTUP_ARTIFACT_DIR'), '*', 'startup.json'))
      expect(records.length).to eq(1)
      expect(JSON.parse(File.read(records.first))).to include('captured_bytes' => 0, 'error_class' => original_error.class.name)
    end

    it('bounds retained startup output and preserves private file and directory permissions') do
      bytes = "head-marker#{'x' * BrowserStartupDiagnostics::LOG_BYTES}tail-marker\n"
      diagnostics.service.log.write(bytes)
      diagnostics.retain(original_error)
      retained = Dir.glob(File.join(ENV.fetch('BROWSER_STARTUP_ARTIFACT_DIR'), '*')).fetch(0)
      files = Dir.children(retained).map { |name| File.join(retained, name) }
      expect(File.stat(retained).mode & 0o777).to eq(0o700)
      expect(files.map { |file| File.stat(file).mode & 0o777 }).to eq([0o600, 0o600])
      expect(File.size(File.join(retained, 'chromedriver-startup.log'))).to eq(described_class::LOG_BYTES)
      expect(File.binread(File.join(retained, 'chromedriver-startup.log'))).to eq(bytes.byteslice(-described_class::LOG_BYTES, described_class::LOG_BYTES))
      expect(JSON.parse(File.read(File.join(retained, 'startup.json')))).to include('truncated' => true)
    end

    it('refuses an existing log without truncating its contents') do
      path = File.join(directory, 'chromedriver-startup.log')
      File.write(path, 'existing owned evidence')
      expect { diagnostics }.to raise_error(Errno::EEXIST)
      expect(File.read(path)).to eq('existing owned evidence')
    end

    it('refuses a symlinked scratch directory') do
      path = File.join(directory, 'linked')
      File.symlink(directory, path)
      expect { described_class.new(path, 'fixture') }.to raise_error(/unsafe browser diagnostic directory/)
      expect(File).not_to exist(File.join(directory, 'chromedriver-startup.log'))
    end

    it('refuses replaced log identity without retaining foreign bytes') do
      diagnostics.service.log.write('owned bytes')
      path = File.join(directory, 'chromedriver-startup.log')
      File.rename(path, "#{path}.original")
      File.write(path, 'foreign bytes', perm: 0o600)
      expect { diagnostics.retain(original_error) }.to output(/retention failed: RuntimeError/).to_stderr
      expect(File).not_to exist(ENV.fetch('BROWSER_STARTUP_ARTIFACT_DIR'))
    end

    it('retains the original exception when the diagnostic destination is unsafe') do
      File.symlink(directory, ENV.fetch('BROWSER_STARTUP_ARTIFACT_DIR'))
      fixture = prepared_fixture(RequestSecurity)
      expect { fixture.__send__(:start_browser) }.to raise_error(original_error) { |caught| expect(caught).to equal(original_error) }
      expect(Dir.children(directory)).not_to include('startup.json')
    end

    it('prints only bounded native errors without protocol or credential-shaped lines') do
      lines = ["[123:ERROR:startup.cc:1] native refusal\n", "[123:ERROR:startup.cc:1] token=synthetic-marker\n",
               "[123:ERROR:startup.cc:1] api_key=synthetic-api-key\n", "[123:ERROR:startup.cc:1] unfamiliar_credential=synthetic-unknown\n",
               "[123:ERROR:startup.cc:1] https://fixture.invalid\n", "[DEBUG] protocol ERROR: synthetic-payload\n"]
      diagnostics.service.log.write(lines.join)
      observation = StringIO.new
      allow(diagnostics).to receive(:warn) { |line| observation.puts(line) }
      diagnostics.retain(original_error)
      expect(observation.string).not_to include('synthetic-api-key', 'synthetic-unknown')
      expected = lines.first(5).map { |line| "Browser native startup: sha256=#{Digest::SHA256.hexdigest(line)}" }
      expect(observation.string.lines.grep(/\ABrowser native startup:/).map(&:strip)).to eq(expected)
      expect(observation.string).not_to include('native refusal', 'synthetic-marker', 'https://fixture.invalid', 'synthetic-payload')
      log = File.join(ENV.fetch('BROWSER_STARTUP_ARTIFACT_DIR'), '*', 'chromedriver-startup.log')
      expect(File.read(Dir.glob(log).fetch(0))).to eq(lines.join)
    end
  end

  context 'with exclusive short scratch creation' do
    before { allow(Dir).to receive(:tmpdir).and_return(directory) }

    it('preserves an existing directory when its short random name collides') do
      allow(SecureRandom).to receive(:hex).with(4).and_return('abcdef12')
      existing = File.join(directory, 'abcdef12')
      Dir.mkdir(existing, 0o700)
      File.write(File.join(existing, 'foreign'), 'preserved', mode: 'wx', perm: 0o600)
      expect { BrowserFixtureScratch.create }.to raise_error(Errno::EEXIST)
      expect(File.read(File.join(existing, 'foreign'))).to eq('preserved')
    end

    it('refuses an overlong temporary parent before creating a browser directory') do
      parent = File.join(directory, 'x' * 200)
      Dir.mkdir(parent, 0o700)
      allow(Dir).to receive(:tmpdir).and_return(parent)
      expect { BrowserFixtureScratch.create }.to raise_error(/exceeds Chrome socket capacity/)
      expect(Dir.children(parent)).to be_empty
    end
  end
end
