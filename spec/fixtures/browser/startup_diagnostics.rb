# frozen_string_literal: true

require 'digest'
require 'json'
require 'tmpdir'

# Passes temporary paths only to our native driver and its browser children.
class BrowserFixtureServiceManager < Selenium::WebDriver::ServiceManager
  def initialize(config)
    @temporary_directory = config.temporary_directory
    super
  end

  private

  def build_process(*command)
    environment = { 'TMPDIR' => @temporary_directory, 'TMP' => @temporary_directory, 'TEMP' => @temporary_directory }
    super(environment, *command)
  end
end

# Keeps Selenium's original startup, process-group and shutdown implementation.
class BrowserFixtureChromeService < Selenium::WebDriver::Chrome::Service
  attr_reader :temporary_directory

  def initialize(temporary_directory:, **)
    @temporary_directory = temporary_directory
    super(**)
  end

  def launch
    self.executable_path ||= Selenium::WebDriver::DriverFinder.new(nil, self).driver_path
    BrowserFixtureServiceManager.new(self).tap(&:start)
  end
end

# Retains only startup observations; browser protocol output stays private.
class BrowserStartupDiagnostics
  LOG_BYTES = 65_536
  NATIVE_ERROR = /\A(?:\[[^\]\r\n]{1,160}:(?:ERROR|FATAL):|chrome_crashpad_handler:)/

  # @param scratch [String] existing fixture-owned private directory
  # @param token [String] existing fixture identity
  def initialize(scratch, token)
    @scratch = scratch
    @token = token
    @scratch_identity = private_directory(scratch)
    @log = File.open(File.join(scratch, 'chromedriver-startup.log'), 'wx+', 0o600)
    @log.sync = true
  end

  # @param path [String, nil] original selected ChromeDriver path
  # @return [Selenium::WebDriver::Chrome::Service]
  def service(path = nil)
    @service ||= BrowserFixtureChromeService.new(temporary_directory: @scratch, path: path, args: ['--verbose'], log: @log)
  end

  # @param failure [Exception] original startup exception, never rewritten
  # @param binaries [Hash] selected browser and driver paths, not environment data
  # @return [void]
  def retain(failure, binaries = {})
    bytes = startup_bytes
    directory = retained_directory
    record = observation(failure, binaries, bytes)
    write_private(File.join(directory, 'chromedriver-startup.log'), bytes)
    write_private(File.join(directory, 'startup.json'), JSON.pretty_generate(record))
    warn "Browser startup diagnostics: #{JSON.generate(record.except(:browser, :driver))}"
    native_errors(bytes).each { |fingerprint| warn "Browser native startup: sha256=#{fingerprint}" }
  rescue StandardError => error
    warn "Browser startup diagnostics retention failed: #{error.class}"
  ensure
    close
  end

  # @return [void] close our parent descriptor without changing driver lifetime
  def close
    @log.close unless @log.closed?
  end

  private

  def observation(failure, binaries, bytes)
    binaries.merge(error_class: failure.class.name, error_sha256: Digest::SHA256.hexdigest(failure.message),
                   captured_bytes: bytes.bytesize, log_sha256: Digest::SHA256.hexdigest(bytes), truncated: @log.stat.size > LOG_BYTES)
  end

  def private_directory(path)
    stat = File.lstat(path)
    raise 'Refusing unsafe browser diagnostic directory' unless stat.directory? && stat.uid == Process.uid && (stat.mode & 0o777) == 0o700

    [stat.dev, stat.ino]
  end

  def startup_bytes
    raise 'Browser diagnostic scratch changed' unless private_directory(@scratch) == @scratch_identity

    stat = File.lstat(File.join(@scratch, 'chromedriver-startup.log'))
    descriptor = @log.stat
    raise 'Browser diagnostic log changed' unless stat.file? && [stat.dev, stat.ino] == [descriptor.dev, descriptor.ino] && (stat.mode & 0o777) == 0o600

    @log.flush
    @log.seek([@log.stat.size - LOG_BYTES, 0].max)
    @log.read(LOG_BYTES) || ''.b
  end

  def retained_directory
    root = ENV.fetch('BROWSER_STARTUP_ARTIFACT_DIR', File.expand_path('../../../tmp/browser-startup-diagnostics', __dir__))
    Dir.mkdir(root, 0o700) unless File.exist?(root) || File.symlink?(root)
    private_directory(root)
    Dir.mktmpdir("browser-#{@token}-", root)
  end

  def write_private(path, bytes)
    File.open(path, 'wx', 0o600) { |output| output.write(bytes) }
  end

  def native_errors(bytes)
    bytes.encode(Encoding::UTF_8, invalid: :replace, undef: :replace).lines.filter_map do |line|
      Digest::SHA256.hexdigest(line) if line.match?(NATIVE_ERROR)
    end.first(20)
  end
end
