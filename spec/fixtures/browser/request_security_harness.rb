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
require_relative 'startup_diagnostics'
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
  class Failure < RuntimeError
    attr_reader :observation

    # Attach immutable sanitized observer progress to the original refusal.
    def retain(observation) = @observation = observation.freeze
  end

  # Run one bounded native observation with a fixed operation classification.
  def self.capture(arguments, timeout: 1, operation: 'capture') = new(timeout, operation).capture(arguments)

  # Validate the deadline and initialize state before any observer is spawned.
  def initialize(timeout, operation = 'capture')
    raise Failure, 'Process observation requires a finite positive timeout' unless timeout.is_a?(Numeric) && timeout.finite? && timeout.positive?

    @timeout = timeout
    @scratch = nil
    @scratch_identity = nil
    @pid = nil
    @status = nil
    @operation = %w[capture identity groups metadata profiles].include?(operation) ? operation : 'capture'
    @stage = 'spawning'
    @started = nil
    @failure = nil
  end

  def setup_scratch
    @scratch = Dir.mktmpdir('request-security-observer-')
    File.chmod(0o700, @scratch)
    scratch_stat = File.stat(@scratch)
    @scratch_identity = [scratch_stat.dev, scratch_stat.ino]
    @status = nil
  end

  # Capture native ps output and stop and remove only this observer's resources.
  def capture(arguments)
    reset_observation
    setup_scratch
    @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @pid = Process.spawn({ 'LC_ALL' => 'C' }, 'ps', *arguments, pgroup: true,
                                                                out: [File.join(@scratch, 'stdout'), 'wx', 0o600], err: [File.join(@scratch, 'stderr'), 'wx', 0o600])
    @stage = 'waiting'
    raise Failure, 'Process observation timed out' unless RequestSecurityDeadline.wait(@timeout) { reap? }

    @stage = 'reading'
    { output: read('stdout'), error: read('stderr'), exit: @status.exitstatus }
  rescue Failure => error
    retain_failure(error)
    raise
  rescue SystemCallError => error
    raise retain_failure(Failure.new("Process observation unavailable: #{error.class}")), cause: nil
  ensure
    stop
    @failure&.retain(failure_observation)
    cleanup if @scratch
  end

  # Clear prior failure progress before the next native observation.
  def reset_observation
    @failure = nil
    @elapsed = nil
    @stage = 'spawning'
    @started = nil
  end

  # Retain the actual failure and monotonic elapsed time before owned cleanup.
  def retain_failure(error)
    @failure = error
    @elapsed = elapsed
    error
  end

  # Return monotonic elapsed time, or nil before observation starts.
  def elapsed
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started if @started
  end

  # Fixed failure progress only; no arguments, environment, paths or process output.
  def failure_observation
    { operation: @operation, stage: @stage, observer_pid: @pid, elapsed: @elapsed, reaped: !@status.nil?,
      exit: @status&.exitstatus, signal: @status&.termsig, output_bytes: output_size('stdout'), error_bytes: output_size('stderr') }
  end

  # Read size only from a private regular capture beneath unchanged owned scratch.
  def output_size(name)
    return unless @scratch

    directory = File.lstat(@scratch)
    return unless directory.directory? && @scratch_identity == [directory.dev, directory.ino]

    output = File.lstat(File.join(@scratch, name))
    output.size if output.file? && output.uid == Process.uid && (output.mode & 0o777) == 0o600
  rescue Errno::ENOENT, Errno::EACCES
    nil
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

  # Read fresh PID/parent/group/birth identity, distinguishing absence from refusal.
  def self.identity(pid)
    result = capture(['-p', pid, '-o', 'pid=,ppid=,pgid=,lstart='], operation: 'identity')
    output, error, exit_status = result.values_at(:output, :error, :exit)
    return '' if exit_status == 1 && output.empty? && error.empty?

    identity = successful(result).strip
    fields = identity.split
    raise Failure, 'Process observation malformed identity' unless valid_identity?(fields, numbers: 3) && fields.first == pid

    identity
  end

  # Require a successful native process-group inventory containing numeric rows.
  def self.groups
    rows = successful(capture(['-axo', 'pgid='], operation: 'groups')).split
    raise Failure, 'Process observation malformed group table' unless rows.all? { |value| value.match?(/\A\d+\z/) }

    rows
  end

  # Native UID/group/birth readback qualifies ancestry, never profile text alone.
  def self.metadata(pids)
    raise Failure, 'Invalid browser PID inventory' unless pids.size.between?(1, 128) && pids.uniq == pids && pids.all? { |pid| pid.is_a?(Integer) && pid.positive? }

    result = capture(['-ww', '-p', pids.join(','), '-o', 'pid=,ppid=,pgid=,uid=,lstart='], operation: 'metadata')
    successful(result).lines.each_with_object({}) do |line, rows|
      row = metadata_row(line)
      pid = row.fetch(:pid)
      raise Failure, 'Unexpected or duplicate browser native PID' unless pids.include?(pid) && !rows.key?(pid)

      rows[pid] = row
    end
  end

  def self.metadata_row(line)
    fields = line.split
    valid = fields.size == 9 && fields.first(4).all? { |value| value.match?(/\A\d+\z/) }
    valid &&= valid_identity?(fields.values_at(0, 1, 2, 4, 5, 6, 7, 8), numbers: 3)
    raise Failure, 'Malformed browser native metadata' unless valid

    pid, parent, group, uid = fields.first(4).map(&:to_i)
    { pid: pid, ppid: parent, pgid: group, uid: uid, birth: fields.last(5).join(' ') }.freeze
  end

  # Select exact profile arguments from a validated native process table.
  def self.profiles(profile)
    successful(capture(['-ww', '-axo', 'pid=,ppid=,lstart=,command='], operation: 'profiles')).lines.filter_map do |line|
      fields = line.strip.split(/\s+/, 8)
      identity = fields.first(7)
      raise Failure, 'Process observation incomplete profile table' unless fields.length == 8 && valid_identity?(identity, numbers: 2)

      identity.join(' ') if fields.last.match?(/(?:^|\s)#{Regexp.escape(profile)}(?:\s|$)/)
    end
  end
end

# A later renderer is owned through retained native anchors and complete ancestry.
# The profile flag is necessary, but can never make an unrelated process ours.
class RequestSecurityBrowserInventory
  # Retain profile identities and require one root beneath the two native anchors.
  def initialize(anchors, rows)
    @anchors = anchors
    @profiles = rows.map { |line| profile_identity(line) }
    members = @profiles.map { |row| row.fetch(:pid) }
    raise 'Ambiguous browser profile inventory' unless members.size <= 126 && members.uniq.size == members.size

    roots = @anchors.values.select { |row| @anchors.key?(row[:ppid]) }
    raise 'Browser retained anchor identity is ambiguous' unless @anchors.size == 2 && roots.one?

    @root = roots.first
  end

  # Recheck retained anchors and every profile against fresh native metadata.
  def validate(metadata)
    @anchors.each do |pid, expected|
      raise 'Browser retained anchor identity changed or unavailable' unless metadata[pid] == expected
    end
    raise 'Browser retained root profile missing' unless @profiles.any? { |row| row[:pid] == @root[:pid] }

    @profiles.each { |profile| verify_profile(profile, metadata) }
    @profiles
  end

  private

  # Require matching identity, current UID and root group before ancestry checks.
  def verify_profile(profile, metadata)
    actual = metadata[profile[:pid]]
    raise 'Browser profile/native identity changed or unavailable' unless actual && profile.all? { |key, value| actual[key] == value }
    raise 'Browser child owner or group changed' unless actual[:uid] == Process.uid && actual[:pgid] == @root[:pgid]

    verify_ancestry(profile, metadata)
  end

  # Parse only complete native PID/parent/birth profile identity rows.
  def profile_identity(line)
    fields = line.split
    raise 'Malformed browser profile identity' unless RequestSecurityObservation.valid_identity?(fields, numbers: 2)

    { pid: fields[0].to_i, ppid: fields[1].to_i, birth: fields.last(5).join(' ') }
  end

  # Require a complete acyclic chain of profile members back to the retained root.
  def verify_ancestry(profile, metadata)
    members = @profiles.map { |row| row.fetch(:pid) }
    visited = []
    pid = profile[:pid]
    until pid == @root[:pid]
      raise 'Browser child ancestry is foreign, cyclic or incomplete' unless members.include?(pid) && visited.none?(pid)

      visited << pid
      pid = metadata.fetch(pid).fetch(:ppid)
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

  # Let ChromeDriver reap its child while TERM starts our verified shutdown.
  # @return [void] fresh identity/profile checks also apply to asynchronous shutdown
  def request_termination = signal('TERM')

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

    if @owner_check && !@owner_check.call
      return if absent?

      raise "Owned PID #{@pid} profile ownership changed"
    end

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
    @observer_failures = []
    attempt_cleanup(:driver_quit) { quit_browser }
    attempt_cleanup(:chrome) { stop_chrome }
    attempt_cleanup(:driver) { @driver_process&.terminate(timeout: @cleanup_timeout) }
    attempt_cleanup(:server) { stop_server }
    attempt_cleanup(:quit_thread) { finish_quit_thread }
    @log&.close
    @startup_diagnostics&.close
    attempt_cleanup(:absence) { cleanup }
    persist_cleanup
    raise @cleanup_errors.join('; ') unless @cleanup_errors.empty?
  end

  private

  def attempt_cleanup(stage)
    yield
  rescue StandardError => error
    @cleanup_errors << "#{stage}: #{error.class}: #{error.message}"
    @observer_failures << { stage: stage, observation: error.observation } if error.is_a?(RequestSecurityObservation::Failure) && error.observation
  end

  def quit_browser
    return unless @page

    @quit_thread = Thread.new do
      @page.driver.quit
    rescue StandardError => error
      @quit_error = error
    end
    # ChromeDriver must reap its child while our authenticated TERM wakes a
    # custom-profile browser whose graceful close can exceed this deadline.
    captured_chrome_processes.select { |process| process.identity.split[1] == @driver_pid }.each(&:request_termination)
    raise 'driver quit timed out' unless RequestSecurityDeadline.wait(@cleanup_timeout) { !@quit_thread.alive? }
    raise @quit_error if @quit_error
  end

  def stop_chrome
    return unless @scratch

    captured_chrome_processes.each { |process| process.terminate(timeout: @cleanup_timeout) }
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
    @cleanup_record.merge!(database_mode: @database_mode, errors: @cleanup_errors, observer_failures: @observer_failures,
                           process_identities: captured_process_identities, ports: @ports)
    @cleanup_record[:profile] = File.join(@scratch, 'chrome') if @scratch
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
    @scratch = BrowserFixtureScratch.create
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
    @startup_diagnostics = BrowserStartupDiagnostics.new(@scratch, @token)
    service = @startup_diagnostics.service(@driver_binary)
    driver_name = :"request_security_#{@token}"
    Capybara.register_driver(driver_name) { |app| Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, service: service) }
    @page = Capybara::Session.new(driver_name)
    @page.config.default_max_wait_time = 10
    @page.config.app_host = @origin
    @page.driver.browser
    record_browser_ownership
    instrument_browser
  rescue StandardError => error
    @startup_diagnostics&.retain(error, browser: @chrome_binary, driver: @driver_binary)
    raise
  end

  def record_browser_ownership
    return captured_chrome_processes if @chrome_processes

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

    capture_browser_anchors
  end

  # Capture the driver and its unique Chrome root as fresh immutable native anchors.
  def capture_browser_anchors
    roots = @chrome_processes.select { |process| process.identity.split[1] == @driver_pid }
    raise 'Browser captured root is ambiguous' unless roots.one?

    anchors = [@driver_process, roots.first]
    metadata = RequestSecurityObservation.metadata(anchors.map(&:pid))
    anchors.each { |process| verify_browser_capture(process, metadata.fetch(process.pid)) }
    @browser_anchors = metadata.freeze
  end

  # Compare fresh native UID and identity with the originally captured process.
  def verify_browser_capture(process, actual)
    identity = process.identity.split
    expected = { pid: process.pid, ppid: identity[1].to_i, pgid: identity[2].to_i, uid: Process.uid, birth: identity.last(5).join(' ') }
    raise 'Browser capture native identity changed' unless actual == expected
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

  # Admit later profile members only after validating the complete native ancestry.
  def captured_chrome_processes
    captured = Array(@chrome_processes)
    rows = owned_browser_processes
    unexpected = rows.map { |line| line.split.first.to_i } - captured.map(&:pid)
    return captured if unexpected.empty?

    metadata = validated_browser_profiles(rows)
    later = unexpected.map { |pid| capture_later_browser(pid, metadata.fetch(pid)) }
    @chrome_processes = captured + later
  end

  # Bind a later child's signals to its admitted identity and fresh ownership check.
  def capture_later_browser(pid, actual)
    admitted = actual.merge(birth: actual.fetch(:birth).dup.freeze).freeze
    process = RequestSecurityProcess.new(pid, owner_check: -> { later_browser_owned?(pid, admitted) })
    verify_browser_capture(process, admitted)
    process
  end

  # Read fresh metadata for the retained anchors and all observed profile members.
  def validated_browser_profiles(rows)
    raise 'Missing retained browser anchors' unless @browser_anchors

    pids = (rows.map { |line| line.split.first.to_i } + @browser_anchors.keys).uniq
    metadata = RequestSecurityObservation.metadata(pids)
    RequestSecurityBrowserInventory.new(@browser_anchors, rows).validate(metadata)
    metadata
  end

  # Require current profile membership and unchanged admitted identity before signaling.
  def later_browser_owned?(pid, admitted)
    return false if RequestSecurityObservation.identity(pid.to_s).empty?

    rows = owned_browser_processes
    return false unless rows.any? { |line| line.split.first.to_i == pid }

    validated_browser_profiles(rows)[pid] == admitted
  end
end
