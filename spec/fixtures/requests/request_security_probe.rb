# frozen_string_literal: true

# Fresh, DB-free deployed application/CLI probe. No ambient provider configuration.
require 'bundler/setup'
require 'json'
require 'tmpdir'
require 'fileutils'
require 'socket'
require 'securerandom'

mode, profile = ARGV.shift(2)
raise 'Unknown request security probe' unless %w[valid host_control missing blank invalid dummy assets mixed network_guard driver_guard].include?(mode)
raise 'Unknown deployed profile' unless %w[production staging].include?(profile)

root = File.expand_path('../../..', __dir__)
artifact_dir = ENV.fetch('REQUEST_SECURITY_ARTIFACT_DIR', nil)
ENV.keys.grep(/\A(?:AWS_|OTEL_|DATABASE|PRIMARY_DB_|SECRET_KEY_BASE|CLOUDFRONT_|ALLOWED_HOSTS|RAILS_|RACK_|REQUEST_|THRUSTER_|ALB_)|_DATABASE_URL\z/)
   .each { |key| ENV.delete(key) }
ENV.update('RAILS_ENV' => profile, 'RACK_ENV' => profile, 'AWS_BOOTSTRAP_ENABLED' => 'false',
           'AWS_EC2_METADATA_DISABLED' => 'true', 'SECRET_KEY_BASE' => SecureRandom.hex(64),
           'PRIMARY_DB_HOST' => '127.0.0.1', 'DATABASE_NAME' => 'request_security_fixture',
           'DATABASE_PORT' => '19478', 'REQUEST_RATE_LIMIT_ENABLED' => 'false',
           'ACTIVE_STORAGE_STAGING_BUCKET' => 'request-security-staging-fixture',
           'ACTIVE_STORAGE_PRODUCTION_BUCKET' => 'request-security-production-fixture',
           'ACTIVE_STORAGE_S3_REGION' => 'us-east-1')
# Only this DB-free fixture disables quota storage. Genuine asset builds omit runtime ingress.
ENV['REQUEST_INGRESS_PROFILE'] = 'direct' unless mode == 'assets'
ENV['ALLOWED_HOSTS'] = 'app.example.test' if %w[valid host_control network_guard driver_guard].include?(mode)
ENV['ALLOWED_HOSTS'] = ' ' if mode == 'blank'
ENV['ALLOWED_HOSTS'] = '*.example.test' if mode == 'invalid'
ENV['SECRET_KEY_BASE_DUMMY'] = '1' if %w[dummy assets mixed].include?(mode)

require File.join(root, 'spec/fixtures/runtime/smoke')
DependencySmoke.configure_aws
require 'mysql2'
counters = { network: 0, database: 0 }
Mysql2::Client.define_singleton_method(:new) do |*|
  counters[:database] += 1
  raise 'Request security database guard reached'
end
[[TCPSocket, :new], [Socket, :tcp], [UDPSocket, :new]].each do |klass, method|
  klass.define_singleton_method(method) do |*|
    counters[:network] += 1
    raise 'Request security network guard reached'
  end
end
Socket.prepend(Module.new do
  define_method(:connect) do |*|
    counters[:network] += 1
    raise 'Request security network guard reached'
  end
  define_method(:connect_nonblock) do |*|
    counters[:network] += 1
    raise 'Request security network guard reached'
  end
end)

scratch = Dir.mktmpdir('railsstarter-request-security-cli-')
File.chmod(0o700, scratch)
token = SecureRandom.hex(16)
File.write(File.join(scratch, 'owner'), token, mode: 'wx', perm: 0o600)
result = { mode: mode, profile: profile, pid: Process.pid, cwd: root }
begin
  TCPSocket.new('127.0.0.1', 19_478) if mode == 'network_guard'
  Mysql2::Client.new if mode == 'driver_guard'
  require File.join(root, 'config/application')
  app = Rails.application
  app.config.paths['log'] = File.join(scratch, 'app.log')
  app.config.paths['tmp'] = scratch
  app.config.paths['tmp/cache'] = File.join(scratch, 'cache')
  app.config.assets.output_path = Pathname.new(File.join(scratch, 'assets'))
  app.config.assets.manifest_path = app.config.assets.output_path.join('.manifest.json')
  app.config.middleware.delete(ActionDispatch::HostAuthorization) if mode == 'host_control'
  if %w[assets mixed].include?(mode)
    # The original Rails command is executed, not an environment-only task impersonation.
    ARGV.replace(mode == 'mixed' ? %w[assets:precompile environment] : ['assets:precompile'])
    load File.join(root, 'bin/rails')
    result[:manifest_created] = app.config.assets.manifest_path.file?
    result[:asset_count] = JSON.parse(File.read(app.config.assets.manifest_path)).size if result[:manifest_created]
  elsif mode == 'dummy'
    ARGV.replace(['runner', "raise 'Request security dummy runner reached runtime'"])
    load File.join(root, 'bin/rails')
  else
    app.initialize!
    require 'rack/mock'
    requests = [
      ['allowed', '/', 'app.example.test', nil], ['unexpected', '/', 'unexpected.test', nil],
      ['forwarded', '/', 'app.example.test', 'unexpected.test'],
      ['health', '/up?query=1', 'unexpected.test', nil],
      ['health_slash', '/up/', 'unexpected.test', nil], ['neighbor', '/up-other', 'unexpected.test', nil],
      ['encoded', '/%75p', 'unexpected.test', nil], ['upper', '/UP', 'unexpected.test', nil]
    ]
    result[:responses] = requests.to_h do |name, path, host, forwarded|
      response = Rack::MockRequest.new(app).get(path, 'HTTP_HOST' => host,
                                                      'REMOTE_ADDR' => '127.0.0.1',
                                                      'HTTP_X_FORWARDED_HOST' => forwarded,
                                                      'HTTP_ACCEPT' => name == 'health' ? 'application/json' : 'text/html')
      [name, { status: response.status, csp: response['content-security-policy'], body: response.body[0, 500] }]
    end
    result[:hosts] = app.config.hosts
    result[:middleware] = app.middleware.map { |entry| entry.klass.name }
    result[:assume_ssl] = app.config.assume_ssl
    result[:force_ssl] = app.config.force_ssl
    terminal = ->(_) { [200, { 'content-type' => 'text/plain' }, ['owned SSL observation']] }
    ssl = ActionDispatch::SSL.new(terminal, **app.config.ssl_options)
    without_exclusion = ActionDispatch::SSL.new(terminal)
    result[:ssl] = ['/up?query=1', '/', '/up/', '/up-other'].index_with do |path|
      Rack::MockRequest.new(ssl).get(path, 'HTTP_HOST' => 'app.example.test').status
    end
    result[:ssl_control_without_exclusion] = Rack::MockRequest.new(without_exclusion).get('/up').status
  end
  result[:booted] = app.initialized?
rescue StandardError => error
  result[:error_class] = error.class.name
  result[:error] = error.message if error.is_a?(ArgumentError) || error.message.start_with?('Request security ')
ensure
  result[:aws] = DependencySmoke.aws_evidence
  result[:guards] = counters
  raise 'Refusing unowned CLI scratch cleanup' unless File.read(File.join(scratch, 'owner')) == token

  FileUtils.remove_entry_secure(scratch)
  result[:scratch_removed] = !File.exist?(scratch)
  if artifact_dir
    File.write(File.join(artifact_dir, "request-#{profile}-#{mode}-#{Process.pid}.json"),
               JSON.pretty_generate(result), mode: 'wx', perm: 0o600)
  end
  puts "REQUEST_SECURITY_RESULT=#{JSON.generate(result)}" # rubocop:disable RSpec/Output -- Standalone CLI observation.
end
exit(result[:error_class] ? 1 : 0)
