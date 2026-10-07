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

# Owns one real Rails process and one fresh browser per example, without a DB.
class BootstrapAssets
  attr_reader :page, :source

  # @return [void] start the guarded real app and our browser
  def start
    setup_scratch
    spawn_server
    wait_for_server
    validate_runtime!
    @source = File.read(File.join(@root, 'app/views/layouts/application.html.erb'))
    start_browser
  end

  # @return [void] stop only our unreaped child and token-proved scratch
  def stop
    @page&.driver&.quit
    stop_server
  ensure
    @startup_diagnostics&.close
    cleanup_scratch
  end

  private

  def setup_scratch
    @root = File.expand_path('../../..', __dir__)
    @scratch = Dir.mktmpdir('railsstarter-bootstrap-browser-')
    File.chmod(0o700, @scratch)
    @token = SecureRandom.hex(16)
    File.write(File.join(@scratch, 'owner.json'), JSON.generate(token: @token), mode: 'wx', perm: 0o600)
    FileUtils.mkdir_p(File.join(@scratch, 'views', 'layouts'))
    socket = TCPServer.new('127.0.0.1', 0)
    @port = socket.addr[1]
    socket.close
  end

  def environment
    inherited = ENV.to_h.select do |key, _|
      key.match?(/\A(?:AWS_|OTEL_|DATABASE|PRIMARY_DB_HOST|CLOUDFRONT_ENDPOINT)|_DATABASE_URL\z/)
    end
    inherited.transform_values { nil }.merge(
      'RAILS_ENV' => 'test', 'RACK_ENV' => 'test', 'RUNTIME_SMOKE_DB' => '0', 'RUNTIME_SMOKE_IMAGE' => '0',
      'REQUEST_RATE_LIMIT_ENABLED' => 'false',
      'SECRET_KEY_BASE_DUMMY' => nil, 'DATABASE_NAME' => "railsstarter_63_smoke_b81_#{SecureRandom.hex(4)}",
      'PRIMARY_DB_HOST' => '127.0.0.1', 'DATABASE_PORT' => '19481',
      'BOOTSTRAP_BROWSER_SCRATCH' => @scratch, 'BOOTSTRAP_BROWSER_TOKEN' => @token,
      'BOOTSTRAP_BROWSER_PORT' => @port.to_s
    )
  end

  def spawn_server
    @pid = Process.spawn(environment, RbConfig.ruby, File.join(@root, 'spec/fixtures/browser/bootstrap_server.rb'),
                         chdir: @root, out: File.join(@scratch, 'server.log'), err: [:child, :out])
  end

  def wait_for_server
    Timeout.timeout(30) do
      loop do
        begin
          break if Net::HTTP.get_response(URI("http://127.0.0.1:#{@port}/up")).code == '200'
        rescue Errno::ECONNREFUSED
          raise File.read(File.join(@scratch, 'server.log')) if Process.waitpid(@pid, Process::WNOHANG)
        end
        sleep 0.1
      end
    end
  end

  def read_owner
    JSON.parse(File.read(File.join(@scratch, 'server-owner.json')))
  end

  def validate_owner!(owner)
    raise 'Owned browser server readback failed' unless owner.values_at('token', 'pid', 'cwd', 'port') == [@token, @pid, @root, @port]
  end

  def validate_runtime!
    owner = read_owner
    validate_owner!(owner)
    expected = { 'bootstrap_enabled' => 'false', 'stub_responses' => true, 'requests' => [], 'fixture_consumed' => nil }
    raise 'Browser boot made AWS requests or consumed remote configuration' unless owner.fetch('aws') == expected
  end

  def browser_options
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless=new')
    options.add_argument('--window-size=800,900')
    options.add_option('goog:loggingPrefs', browser: 'ALL', performance: 'ALL')
    options
  end

  def start_browser
    args = { browser: :chrome, options: browser_options }
    @startup_diagnostics = BrowserStartupDiagnostics.new(@scratch, @token)
    args[:service] = @startup_diagnostics.service(ENV.fetch('CHROMEDRIVER', nil))
    name = :"bootstrap_#{@token}"
    Capybara.register_driver(name) { |app| Capybara::Selenium::Driver.new(app, **args) }
    @page = Capybara::Session.new(name)
    @page.config.default_max_wait_time = 10
    @page.config.app_host = "http://127.0.0.1:#{@port}"
    @page.driver.browser
  rescue StandardError => error
    @startup_diagnostics&.retain(error, browser: args[:options].binary, driver: args[:service]&.executable_path)
    raise
  end

  def stop_server
    return unless @pid && Process.waitpid(@pid, Process::WNOHANG).nil?

    validate_owner!(read_owner) if File.exist?(File.join(@scratch, 'server-owner.json'))
    # waitpid proves this is still our child, not a recycled ambient PID.
    Process.kill('TERM', @pid)
    @reaped = Process.waitpid(@pid) == @pid
  rescue Errno::ECHILD
    nil # A failed boot was already reaped by the readiness check.
  end

  def cleanup_scratch
    return unless @scratch && File.exist?(File.join(@scratch, 'owner.json'))

    raise 'Refusing unowned scratch cleanup' unless JSON.parse(File.read(File.join(@scratch, 'owner.json')))['token'] == @token

    FileUtils.remove_entry_secure(@scratch)
    raise 'Owned scratch remains after cleanup' if File.exist?(@scratch)

    record_cleanup
  end

  def record_cleanup
    file = ENV.fetch('BOOTSTRAP_BROWSER_CLEANUP_REPORT', nil)
    return unless file

    observation = { pid: @pid, port: @port, cwd: @root, owned_child_reaped: @reaped,
                    scratch: @scratch, token_verified: true, scratch_removed: !File.exist?(@scratch),
                    database_mode: false }
    File.open(file, 'a') { |output| output.puts(JSON.generate(observation)) }
  end
end
