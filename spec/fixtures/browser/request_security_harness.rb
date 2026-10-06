# frozen_string_literal: true

require 'capybara'
require 'selenium-webdriver'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'socket'
require 'net/http'
require 'securerandom'
require 'rbconfig'
require 'timeout'
require 'time'

# Public caller prerequisites shared by supported macOS and Linux runners.
class RequestSecurityExecutable
  # @param environment [Hash]
  # @param platform [String]
  # @return [String] verified browser executable, without automatic installation
  def self.chrome(environment = ENV, platform = RUBY_PLATFORM)
    return verified(environment['CHROME_BIN'], 'CHROME_BIN') if environment.key?('CHROME_BIN')

    candidates = paths(environment, %w[google-chrome google-chrome-stable chromium chromium-browser])
    candidates << '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' if platform.include?('darwin')
    candidates.find { |path| executable?(path) } || raise('Missing Chrome executable; set CHROME_BIN or install Chrome on PATH')
  end

  # @param environment [Hash]
  # @return [String]
  def self.driver(environment = ENV)
    return verified(environment['CHROMEDRIVER'], 'CHROMEDRIVER') if environment.key?('CHROMEDRIVER')

    paths(environment, ['chromedriver']).find { |path| executable?(path) } || raise('Missing ChromeDriver executable; set CHROMEDRIVER or install chromedriver on PATH')
  end

  # @param path [String]
  # @param name [String]
  # @return [String]
  def self.verified(path, name)
    raise "#{name} must name an existing executable file" unless executable?(path)

    File.expand_path(path)
  end

  # @param path [String, nil]
  # @return [Boolean]
  def self.executable?(path) = path && File.file?(path) && File.executable?(path)

  # @param environment [Hash]
  # @param names [Array<String>]
  # @return [Array<String>]
  def self.paths(environment, names)
    environment.fetch('PATH', '').split(File::PATH_SEPARATOR).flat_map do |directory|
      names.map { |name| File.expand_path(name, directory) }
    end
  end
end

# Uses monotonic deadlines rather than unbounded sleeps or child waits.
class RequestSecurityDeadline
  # @param seconds [Numeric]
  # @yieldreturn [Boolean]
  # @return [Boolean]
  def self.wait(seconds)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
    loop do
      return true if yield
      return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.01
    end
  end
end

# Bounded ps transport owns and reaps only its unreaped direct subprocess.
class RequestSecurityObservation
  class Failure < RuntimeError; end

  def self.capture(arguments, timeout: 1) = new(timeout).capture(arguments)

  def initialize(timeout)
    raise Failure, 'Process observation requires a finite positive timeout' unless timeout.is_a?(Numeric) && timeout.finite? && timeout.positive?

    @timeout = timeout
    @scratch = nil
    @scratch_identity = nil
    @pid = nil
    @status = nil
  end

  def setup_scratch
    @scratch = Dir.mktmpdir('request-security-observer-')
    File.chmod(0o700, @scratch)
    scratch_stat = File.stat(@scratch)
    @scratch_identity = [scratch_stat.dev, scratch_stat.ino]
    @status = nil
  end

  def capture(arguments)
    setup_scratch
    @pid = Process.spawn({ 'LC_ALL' => 'C' }, 'ps', *arguments, pgroup: true,
                                                                out: [File.join(@scratch, 'stdout'), 'wx', 0o600], err: [File.join(@scratch, 'stderr'), 'wx', 0o600])
    raise Failure, 'Process observation timed out' unless RequestSecurityDeadline.wait(@timeout) { reap? }

    { output: read('stdout'), error: read('stderr'), exit: @status.exitstatus }
  rescue SystemCallError => error
    raise Failure, "Process observation unavailable: #{error.class}", cause: nil
  ensure
    stop
    cleanup if @scratch
  end

  def cleanup
    actual = File.lstat(@scratch)
    raise Failure, 'Process observation scratch ownership changed' unless actual.directory? && @scratch_identity == [actual.dev, actual.ino]

    FileUtils.remove_entry_secure(@scratch)
    raise Failure, 'Process observation scratch remains' if File.exist?(@scratch)
  end

  def read(name)
    output = File.binread(File.join(@scratch, name), 1_048_577).to_s
    raise Failure, 'Process observation output incomplete: limit exceeded' if output.bytesize > 1_048_576

    output
  end

  def reap?
    return true if @status

    result = Process.waitpid2(@pid, Process::WNOHANG)
    return false unless result

    @status = result.last
    true
  end

  def stop
    return if !@pid || reap?

    signal('TERM')
    return if RequestSecurityDeadline.wait(0.2) { reap? }

    signal('KILL')
    raise Failure, 'Process observation subprocess remains after bounded KILL' unless RequestSecurityDeadline.wait(0.5) { reap? }
  end

  def signal(name)
    # An unreaped direct child cannot have its PID reused; no observer is needed to own it.
    Process.kill(name, @pid) unless reap?
  rescue Errno::ESRCH
    raise unless reap?
  end

  def self.successful(result)
    output, error, exit_status = result.values_at(:output, :error, :exit)
    raise Failure, "Process observation failed: exit=#{exit_status} stderr=#{error.inspect}" unless exit_status == 0 && error.empty?
    raise Failure, 'Process observation incomplete: empty successful output' if output.strip.empty?

    output
  end

  def self.valid_identity?(fields, numbers:)
    return false unless fields.length == numbers + 5 && fields.first(numbers).each_with_index.all? do |value, index|
      value.match?(index == 1 ? /\A\d+\z/ : /\A[1-9]\d*\z/)
    end

    birth = fields.last(5).join(' ')
    Time.strptime(birth, '%a %b %e %H:%M:%S %Y').strftime('%a %b %-d %H:%M:%S %Y') == birth
  rescue ArgumentError
    false
  end

  def self.identity(pid)
    result = capture(['-p', pid, '-o', 'pid=,ppid=,pgid=,lstart='])
    output, error, exit_status = result.values_at(:output, :error, :exit)
    return '' if exit_status == 1 && output.empty? && error.empty?

    identity = successful(result).strip
    fields = identity.split
    raise Failure, 'Process observation malformed identity' unless valid_identity?(fields, numbers: 3) && fields.first == pid

    identity
  end

  def self.groups
    rows = successful(capture(['-axo', 'pgid='])).split
    raise Failure, 'Process observation malformed group table' unless rows.all? { |value| value.match?(/\A\d+\z/) }

    rows
  end

  def self.profiles(profile)
    successful(capture(['-ww', '-axo', 'pid=,ppid=,lstart=,command='])).lines.filter_map do |line|
      fields = line.strip.split(/\s+/, 8)
      identity = fields.first(7)
      raise Failure, 'Process observation incomplete profile table' unless fields.length == 8 && valid_identity?(identity, numbers: 2)

      identity.join(' ') if fields.last.match?(/(?:^|\s)#{Regexp.escape(profile)}(?:\s|$)/)
    end
  end
end

# Signals only a captured PID with its original start time and process group.
class RequestSecurityProcess
  attr_reader :pid, :identity, :signals, :reaped, :status

  # @param pid [Integer]
  # @param child [Boolean] explicit direct-child ownership permits WNOHANG reaping
  # @param owner_check [Proc, nil] validates profile ownership immediately before each signal
  def initialize(pid, child: false, owner_check: nil)
    @pid = pid
    @identity = current_identity
    @child = child
    @owner_check = owner_check
    @signals = []
    raise 'Owned process missing at capture' if @identity.empty?
    raise 'Owned process is not our direct child' if child && @identity.split[1] != Process.pid.to_s
  end

  # @param timeout [Numeric]
  # @return [void]
  def terminate(timeout:)
    return if absent?

    signal('TERM')
    return if RequestSecurityDeadline.wait(timeout) { reap_or_absent? }

    signal('KILL')
    raise "Owned PID #{@pid} remains after bounded KILL" unless RequestSecurityDeadline.wait(timeout) { reap_or_absent? }
  end

  # @return [Boolean] positive OS absence readback, including after successful reap
  def absent? = current_identity.empty?

  # @return [Boolean] reap only this originally captured direct child
  def exited? = reap_or_absent?

  private

  def current_identity
    RequestSecurityObservation.identity(@pid.to_s)
  end

  def matching_identity?
    # Reparenting is normal after driver exit; PID, group and start must match.
    actual = current_identity.split
    return false if actual.empty?

    raise "Owned PID #{@pid} parent identity changed" if @child && actual[1] != Process.pid.to_s

    expected = @identity.split
    raise "Owned PID #{@pid} identity changed" unless actual.values_at(0, 2, 3, 4, 5, 6, 7) == expected.values_at(0, 2, 3, 4, 5, 6, 7)

    true
  end

  def signal(name)
    return unless matching_identity?

    raise "Owned PID #{@pid} profile ownership changed" if @owner_check && !@owner_check.call

    Process.kill(name, @pid)
    @signals << name
  rescue Errno::ESRCH
    raise unless absent?
  end

  def reap_or_absent?
    return true if absent?

    return true unless matching_identity?

    if @child
      result = Process.waitpid2(@pid, Process::WNOHANG)
      if result
        @reaped = true
        @status = result.last
      end
    end
    absent?
  end
end

# Teardown stays separate from application setup; failures are recorded and raised.
module RequestSecurityCleanup
  # @return [void]
  def stop
    @cleanup_errors = []
    attempt_cleanup(:driver_quit) { quit_browser }
    attempt_cleanup(:chrome) { stop_chrome }
    attempt_cleanup(:driver) { @driver_process&.terminate(timeout: @cleanup_timeout) }
    attempt_cleanup(:server) { stop_server }
    attempt_cleanup(:quit_thread) { finish_quit_thread }
    @log&.close
    attempt_cleanup(:absence) { cleanup }
    persist_cleanup
    raise @cleanup_errors.join('; ') unless @cleanup_errors.empty?
  end

  private

  def attempt_cleanup(stage)
    yield
  rescue StandardError => error
    @cleanup_errors << "#{stage}: #{error.class}: #{error.message}"
  end

  def quit_browser
    return unless @page

    @quit_thread = Thread.new do
      @page.driver.quit
    rescue StandardError => error
      @quit_error = error
    end
    raise 'driver quit timed out' unless RequestSecurityDeadline.wait(@cleanup_timeout) { !@quit_thread.alive? }
    raise @quit_error if @quit_error
  end

  def stop_chrome
    return unless @scratch

    captured = Array(@chrome_processes)
    unexpected = owned_browser_processes.map { |line| line.split.first.to_i } - captured.map(&:pid)
    raise 'Uncaptured Chrome profile process; refusing escalation' unless unexpected.empty?

    captured.each { |process| process.terminate(timeout: @cleanup_timeout) }
  end

  def stop_server
    return unless @server_process

    validate_owner! if File.exist?(File.join(@scratch, 'server-owner.json')) && !@server_process.absent?
    @server_process.terminate(timeout: @cleanup_timeout)
    @reaped = @server_process.reaped
  end

  def finish_quit_thread
    return unless @quit_thread&.alive?

    @quit_thread.kill
    raise 'Owned quit thread remains after bounded cancellation' unless RequestSecurityDeadline.wait(@cleanup_timeout) { !@quit_thread.alive? }
    raise @quit_error if @quit_error
  end

  def cleanup
    return unless @scratch

    validate_scratch!
    verify_processes_absent!
    verify_ports_closed
    @cleanup_record = { pid: @pid, ports: @ports, identity: @started_identity, owned_child_reaped: @reaped,
                        browser_processes_before_quit: @browser_processes, browser_processes_after_quit: owned_browser_processes,
                        driver_pid: @driver_pid, driver_identity: @driver_identity, driver_absent_after_quit: @driver_process&.absent?,
                        quit_thread_absent: !@quit_thread&.alive?, server_absent: @server_process&.absent?, process_group_absent: @pid ? true : nil,
                        scratch: @scratch, token_verified: true, signals: teardown_signals }
    FileUtils.remove_entry_secure(@scratch)
    @cleanup_record[:scratch_removed] = !File.exist?(@scratch)
    raise 'Owned scratch remains after deletion' unless @cleanup_record[:scratch_removed]
  end

  def teardown_signals
    [@server_process, @driver_process, *Array(@chrome_processes)].compact.to_h { |process| [process.pid, process.signals] }
  end

  def captured_process_identities = [@server_process, @driver_process, *Array(@chrome_processes)].compact.to_h { |process| [process.pid, process.identity] }

  def persist_cleanup
    @cleanup_record ||= { scratch: @scratch, scratch_removed: false }
    @cleanup_record[:database_mode] = @database_mode
    @cleanup_record[:errors] = @cleanup_errors
    @cleanup_record[:process_identities] = captured_process_identities
    @cleanup_record[:profile] = File.join(@scratch, 'chrome') if @scratch
    @cleanup_record[:ports] = @ports
    dir = ENV.fetch('REQUEST_SECURITY_ARTIFACT_DIR', nil)
    return unless dir && @token

    File.write(File.join(dir, "cleanup-#{@token}.json"), JSON.pretty_generate(@cleanup_record), mode: 'wx', perm: 0o600)
  end

  def validate_scratch!
    owner_file = File.join(@scratch, 'owner.json')
    raise 'Refusing unsafe browser scratch cleanup' if File.symlink?(@scratch) || File.symlink?(owner_file)
    raise 'Refusing unowned browser scratch cleanup' unless JSON.parse(File.read(owner_file))['token'] == @token
  end

  def verify_processes_absent!
    processes = [@server_process, @driver_process, *Array(@chrome_processes)].compact
    raise 'Owned process remains after teardown' unless processes.all?(&:absent?)
    raise 'Owned Chrome profile remains after teardown' unless owned_browser_processes.empty?
    raise 'Owned quit thread remains' if @quit_thread&.alive?
    return unless @pid

    groups = RequestSecurityObservation.groups
    raise 'Server process group remains after teardown' if groups.include?(@pid.to_s)
  end

  def verify_ports_closed
    @ports.each do |port|
      socket = Socket.tcp('127.0.0.1', port, connect_timeout: @cleanup_timeout)
      socket.close
      raise 'Owned server port still open after reap'
    rescue Errno::ECONNREFUSED
      nil
    end
  end
end

# Owns a real application and a fresh Chrome profile for the CSP journey.
class RequestSecurity
  include RequestSecurityCleanup

  attr_reader :page, :origin, :other_origin, :cleanup_record

  # @param cleanup_timeout [Numeric] independent harness deadline, not an application rate limit
  # @param [Hash{Symbol => Object}] throttle_environment
  def initialize(cleanup_timeout: 5, throttle_environment: {})
    @cleanup_timeout = cleanup_timeout
    @throttle_environment = throttle_environment
    @database_mode = nil
  end

  # @return [void]
  def start
    @chrome_binary = RequestSecurityExecutable.chrome
    @driver_binary = RequestSecurityExecutable.driver
    setup_scratch
    @log = File.open(File.join(@scratch, 'server.log'), 'wx', 0o600)
    @pid = Process.spawn(environment, RbConfig.ruby, File.join(__dir__, 'request_security_server.rb'),
                         chdir: @root, pgroup: true, out: @log, err: [:child, :out])
    @server_process = RequestSecurityProcess.new(@pid, child: true)
    @started_identity = @server_process.identity
    wait_for_server
    validate_owner!
    start_browser
  end

  # @return [void]
  def setup_scratch
    @root = @throttle_environment.fetch('REQUEST_RATE_ROOT', File.expand_path('../../..', __dir__))
    @scratch = Dir.mktmpdir('railsstarter-request-security-browser-')
    File.chmod(0o700, @scratch)
    @token = SecureRandom.hex(16)
    @ports = Array.new(2) do
      socket = TCPServer.new('127.0.0.1', 0)
      port = socket.addr[1]
      socket.close
      port
    end
    @origin, @other_origin = @ports.map { |port| "http://127.0.0.1:#{port}" }
    File.write(File.join(@scratch, 'owner.json'), JSON.generate(token: @token), mode: 'wx', perm: 0o600)
  end

  # @return [Hash] actual request headers/body from our live endpoint
  def response(path = '/')
    response = Net::HTTP.get_response(URI(@origin + path))
    { status: response.code.to_i, csp: response['content-security-policy'], body: response.body }
  end

  # @return [Array<Hash>] document-start collected CSP events
  def violations = @page.evaluate_script('window.__requestSecurityViolations || []')

  # @return [Array<String>]
  def errors = @page.driver.browser.logs.get(:browser).select { |entry| entry.level == 'SEVERE' }.map(&:message)

  # @param name [String]
  # @return [void] persist current runtime observations only, never an independent verdict
  def capture(name)
    dir = ENV.fetch('REQUEST_SECURITY_ARTIFACT_DIR', nil)
    return unless dir

    base = File.join(dir, "browser-#{@token}-#{name}")
    @page.save_screenshot("#{base}.png")
    File.chmod(0o600, "#{base}.png")
    state = @page.evaluate_script('({navDisplay: document.querySelector("nav") && getComputedStyle(document.querySelector("nav")).display, bootstrap: !!window.bootstrap})')
    File.write("#{base}.json", JSON.pretty_generate(url: @page.current_url, violations: violations,
                                                    network: network_observations, errors: errors, state: state, pid: @pid, ports: @ports),
               mode: 'wx', perm: 0o600)
  end

  private

  def network_observations
    logs = @page.driver.browser.logs.get(:performance).map { |entry| JSON.parse(entry.message)['message'] }
    logs.filter_map do |entry|
      next unless entry['method'] == 'Network.responseReceived'

      response = entry.dig('params', 'response')
      headers = response.fetch('headers', {}).transform_keys(&:downcase)
      response.slice('url', 'status', 'mimeType').merge('csp' => headers['content-security-policy'])
    end
  end

  def environment
    scrub = ENV.to_h.select { |key, _| key.match?(/\A(?:AWS_|OTEL_|DATABASE|PRIMARY_DB_|CLOUDFRONT_|SECRET_KEY_BASE|ALLOWED_HOSTS)|_DATABASE_URL\z/) }
    scrub.transform_values { nil }.merge(
      'RAILS_ENV' => 'test', 'RACK_ENV' => 'test', 'RUNTIME_SMOKE_DB' => '0', 'RUNTIME_SMOKE_IMAGE' => '0', 'REQUEST_RATE_LIMIT_ENABLED' => 'false',
      'DATABASE_NAME' => "railsstarter_63_smoke_c78_#{SecureRandom.hex(4)}", 'PRIMARY_DB_HOST' => '127.0.0.1',
      'DATABASE_PORT' => '19478', 'REQUEST_SECURITY_SCRATCH' => @scratch,
      'REQUEST_SECURITY_TOKEN' => @token, 'REQUEST_SECURITY_PORTS' => @ports.join(',')
    ).merge(@throttle_environment)
  end

  def wait_for_server
    Timeout.timeout(30) do
      loop do
        begin
          break if response('/up')[:status] == 200
        rescue Errno::ECONNREFUSED
          if @server_process.exited?
            @pid = nil
            raise File.read(File.join(@scratch, 'server.log'))
          end
        end
        sleep 0.1
      end
    end
  end

  def validate_owner!
    @database_mode = nil
    owner = JSON.parse(File.read(File.join(@scratch, 'server-owner.json')))
    raise 'Request security server owner mismatch' unless owner.values_at('token', 'pid', 'cwd', 'ports') == [@token, @pid, @root, @ports]
    raise 'Request security AWS transport used' unless owner.dig('aws', 'requests') == [] && owner.dig('aws', 'stub_responses')

    @database_mode = validated_database_mode(owner)
  end

  def validated_database_mode(owner)
    mode = owner['database_mode']
    raise 'Request security database mode missing or malformed' unless mode.equal?(true) || mode.equal?(false)
    raise 'Request security database mode mismatch' unless mode == @throttle_environment.key?('REQUEST_RATE_ROOT')

    mode
  end

  def start_browser
    options = Selenium::WebDriver::Chrome::Options.new
    options.binary = @chrome_binary
    options.add_argument('--headless=new')
    options.add_argument('--window-size=800,900')
    options.add_argument("--user-data-dir=#{File.join(@scratch, 'chrome')}")
    options.add_option('goog:loggingPrefs', browser: 'ALL', performance: 'ALL')
    service = Selenium::WebDriver::Service.chrome(path: @driver_binary)
    driver_name = :"request_security_#{@token}"
    Capybara.register_driver(driver_name) { |app| Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, service: service) }
    @page = Capybara::Session.new(driver_name)
    @page.config.default_max_wait_time = 10
    @page.config.app_host = @origin
    @page.driver.browser
    record_browser_ownership
    instrument_browser
  end

  def record_browser_ownership
    @browser_processes = owned_browser_processes
    raise 'Fresh owned Chrome profile process not observed' if @browser_processes.empty?

    identities = @browser_processes.map(&:split)
    driver_pids = identities.map { |identity| identity.fetch(1) }.uniq - identities.map(&:first)
    raise 'Fresh browser driver parent ambiguous' unless driver_pids.one?

    capture_browser_processes(driver_pids.first, identities)
  end

  def capture_browser_processes(driver_pid, identities)
    @driver_pid = driver_pid
    @driver_process = RequestSecurityProcess.new(@driver_pid.to_i, child: true)
    @driver_identity = @driver_process.identity
    @chrome_processes = identities.map { |identity| capture_chrome_process(identity.first.to_i) }
    raise 'Browser driver is not our direct child' unless @driver_identity.split[1] == Process.pid.to_s
  end

  def capture_chrome_process(pid)
    owner_check = -> { owned_browser_processes.any? { |line| line.split.first.to_i == pid } }
    RequestSecurityProcess.new(pid, owner_check: owner_check)
  end

  def instrument_browser
    @page.driver.browser.execute_cdp('Page.addScriptToEvaluateOnNewDocument', source: <<~JS)
      window.__requestSecurityViolations = [];
      document.addEventListener('securitypolicyviolation', event => {
        window.__requestSecurityViolations.push({directive: event.effectiveDirective,
          blocked: event.blockedURI, disposition: event.disposition});
      });
    JS
  end

  def owned_browser_processes
    RequestSecurityObservation.profiles("--user-data-dir=#{File.join(@scratch, 'chrome')}")
  end
end
