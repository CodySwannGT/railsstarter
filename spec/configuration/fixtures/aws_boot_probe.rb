# frozen_string_literal: true

# A separate process exercises the real Rails boot; synthetic credentials never leave SDK stubs.
require 'bundler/setup'
require 'json'
require 'tmpdir'
require 'fileutils'
require 'socket'
require 'mysql2'
require 'aws-sdk-ssm'
require 'aws-sdk-cloudformation'
require 'aws-sdk-secretsmanager'

scenario = ARGV.fetch(0)
ENV.keys.grep(/\A(?:AWS_|ACTIVE_STORAGE_|DATABASE_|PRIMARY_DB_|SECRET_KEY_BASE|CLOUDFRONT_|REDIS_|OTEL_|RAILS_|RACK_|BUNDLE_WITHOUT)/).each { |key| ENV.delete(key) }
ENV['AWS_EC2_METADATA_DISABLED'] = 'true'
# Valid exact deployed inputs preserve this fixture's original AWS boot scenarios.
ENV['ALLOWED_HOSTS'] = 'owned67.invalid'
ENV['REQUEST_INGRESS_PROFILE'] = 'direct'
ENV['RAILS_ENV'] = case scenario
                   when 'local' then 'development'
                   when 'test' then 'test'
                   when 'staging' then 'staging'
                   else 'production'
                   end
ENV['AWS_BOOTSTRAP_ENABLED'] = 'true' unless %w[local test assets assets_plain assets_leaked disabled].include?(scenario)
ENV['AWS_BOOTSTRAP_ENABLED'] = 'true' if scenario == 'assets_leaked'
ENV['AWS_BOOTSTRAP_ENABLED'] = 'false' if scenario == 'disabled'
ENV['AWS_REGION'] = 'us-west-2'
ENV['AWS_SSM_PATH'] = '/app/'
ENV['AWS_DATABASE_SECRET_ID'] = 'owned67/database'
ENV['AWS_DATABASE_SECRET_PREFIX'] = 'PipelineStack'
ENV['AWS_SECRET_KEY_BASE_SECRET_ID'] = 'owned67/key'
ENV['AWS_EXPORT_CLOUDFRONT_ENDPOINT'] = 'assetDomainOwned67'
ENV['SECRET_KEY_BASE_DUMMY'] = '1' if %w[assets assets_leaked].include?(scenario)
unless %w[local test assets assets_leaked].include?(scenario)
  ENV['ACTIVE_STORAGE_STAGING_BUCKET'] = 'synthetic-owned67-staging-uploads'
  ENV['ACTIVE_STORAGE_PRODUCTION_BUCKET'] = 'synthetic-owned67-production-uploads'
  ENV['ACTIVE_STORAGE_S3_REGION'] = 'us-west-2'
end
if %w[local test assets assets_plain assets_leaked disabled overrides partial].include?(scenario)
  ENV['DATABASE_USER'] = 'owned67_user'
  ENV['DATABASE_NAME'] = 'owned67_database'
  ENV['PRIMARY_DB_HOST'] = 'owned67.invalid'
  ENV['SECRET_KEY_BASE'] = 'owned67_supplied_key_' * 4
end
if %w[overrides disabled].include?(scenario)
  ENV['DATABASE_PORT'] = '4406'
  ENV['DATABASE_PASSWORD'] = 'owned67_supplied_password'
  ENV['DATABASE_NAME'] = 'owned67_supplied_database'
  ENV['PRIMARY_DB_HOST'] = 'owned67_supplied.invalid'
  ENV['DATABASE_REPLICA_HOST'] = 'owned67_supplied_replica.invalid'
  ENV['CLOUDFRONT_ENDPOINT'] = 'https://supplied.invalid'
end
ENV.delete('AWS_DATABASE_SECRET_ID') if %w[prefix missing_id].include?(scenario)
ENV['AWS_DATABASE_SECRET_PREFIX'] = 'PipelineStack' if scenario == 'prefix'

# Tripwires are installed before any application code; no adapter/schema access is authorized.
counters = { driver: 0, network: 0 }
Mysql2::Client.define_singleton_method(:new) do |*|
  counters[:driver] += 1
  raise 'owned67 database connection forbidden'
end
[[TCPSocket, :new], [Socket, :tcp], [Socket, :getaddrinfo], [UDPSocket, :new]].each do |klass, method|
  klass.define_singleton_method(method) do |*|
    counters[:network] += 1
    raise 'owned67 network connection forbidden'
  end
end
Socket.prepend(Module.new do
  define_method(:connect) do |*|
    counters[:network] += 1
    raise 'owned67 network connection forbidden'
  end

  define_method(:connect_nonblock) do |*|
    counters[:network] += 1
    raise 'owned67 network connection forbidden'
  end
end)

clients = []
Aws.config.update(stub_responses: true, region: 'us-west-2', credentials: Aws::Credentials.new('owned67', 'synthetic'))
ssm_pages = [
  { parameters: [{ name: '/app/early', value: 'early' }], next_token: 'ssm-page-2' },
  { parameters: [{ name: '/app/database_port', value: '4406' },
                 { name: '/app/late', value: 'late' }] }
]
ssm_pages[1][:parameters].reject! { |parameter| parameter[:name] == '/app/database_port' } if scenario == 'secret_port'
if scenario == 'selector_redirect'
  %w[aws_region aws_ssm_path aws_export_cloudfront_endpoint aws_database_secret_id aws_secret_key_base_secret_id].each do |key|
    ssm_pages[1][:parameters] << { name: "/app/#{key}", value: 'untrusted-selector' }
  end
end
ssm_pages[1][:parameters] << { name: '/app/EARLY', value: 'collision' } if scenario == 'ssm_collision'
ssm_pages[1][:parameters] << { name: '/appish/leak', value: 'wrong-prefix' } if scenario == 'ssm_prefix'
exports = [
  { exports: [{ name: 'assetDomainWrong', value: 'https://wrong.invalid' }], next_token: 'cf-page-2' },
  { exports: [{ name: 'assetDomainOwned67', value: 'https://selected.invalid' },
              { name: 'redisCachePort', value: '6380' }] }
]
secret_pages = [
  { secret_list: [{ name: 'PipelineStackWrong' }], next_token: 'secret-page-2' },
  { secret_list: [{ name: 'owned67/database' }, { name: 'owned67/key' }, { name: 'PipelineStackOther' }] }
]
{
  Aws::SSM::Client => { get_parameters_by_path: scenario == 'denied' ? 'AccessDeniedException' : ssm_pages },
  Aws::CloudFormation::Client => { list_exports: exports },
  Aws::SecretsManager::Client => {
    list_secrets: secret_pages,
    get_secret_value: lambda do |context|
      id = context.params[:secret_id]
      if id == 'owned67/key'
        { secret_string: 'owned67_remote_key_' * 4 }
      elsif id == 'rails_secret_key_base'
        { secret_string: 'owned67_wrong_key_' * 4 }
      else
        { secret_string: JSON.generate(username: 'owned67_remote_user', password: 'owned67_remote_password',
                                       dbname: 'owned67_database', host: 'owned67.cluster-example.invalid', port: 4406) }
      end
    end
  }
}.each do |klass, responses|
  original = klass.method(:new)
  klass.define_singleton_method(:new) do |*args, **kwargs|
    client = original.call(*args, **kwargs, stub_responses: true)
    responses.each { |operation, response| client.stub_responses(operation, response) }
    clients << client
    client
  end
end

owned_tmp = Dir.mktmpdir('railsstarter-owned67-')
result = { scenario: scenario }
begin
  if scenario == 'driver_guard'
    Mysql2::Client.new
  elsif scenario == 'network_guard'
    TCPSocket.new('owned67.invalid', 4406)
  end
  ARGV.replace(['assets:precompile']) if %w[assets assets_plain assets_leaked].include?(scenario)
  require_relative '../../../config/application'
  app = Rails.application
  app.config.paths['log'] = File.join(owned_tmp, 'app.log')
  app.config.paths['tmp'] = owned_tmp
  app.config.paths['tmp/cache'] = File.join(owned_tmp, 'cache')
  app.config.assets.output_path = Pathname.new(File.join(owned_tmp, 'assets'))
  app.config.assets.manifest_path = app.config.assets.output_path.join('.manifest.json')
  app.config.secret_key_base = ENV.fetch('SECRET_KEY_BASE', nil) if %w[local test].include?(scenario)
  if %w[assets assets_plain assets_leaked].include?(scenario)
    # The public Rails CLI initializes Rake's real top-level task inventory.
    load File.expand_path('../../../bin/rails', __dir__)
    result[:manifest_created] = app.config.assets.manifest_path.file?
  else
    app.initialize!
    app.eager_load!
  end
  require 'active_record/connection_adapters/mysql2_adapter'
  config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: 'primary').configuration_hash
  replica = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: 'primary_replica', include_hidden: true).configuration_hash
  adapter = ActiveRecord::ConnectionAdapters::Mysql2Adapter.new(config)
  replica_adapter = ActiveRecord::ConnectionAdapters::Mysql2Adapter.new(replica)
  result.merge!(booted: app.initialized?, eager_loaded: %w[assets assets_plain assets_leaked].exclude?(scenario), port: config[:port],
                adapter_port: adapter.instance_variable_get(:@config)[:port],
                replica_adapter_port: replica_adapter.instance_variable_get(:@config)[:port],
                ssm_supplies_port: ssm_pages.flat_map { |page| page[:parameters] }
                                            .any? { |parameter| parameter[:name] == '/app/database_port' },
                late_parameter: ENV['LATE'] == 'late',
                selected_export: app.config.action_controller.asset_host == 'https://selected.invalid',
                supplied_export: app.config.action_controller.asset_host == 'https://supplied.invalid',
                supplied_user: config[:username] == 'owned67_user',
                supplied_password: config[:password] == 'owned67_supplied_password',
                supplied_database: config[:database] == 'owned67_supplied_database',
                supplied_host: config[:host] == 'owned67_supplied.invalid',
                supplied_replica: replica[:host] == 'owned67_supplied_replica.invalid',
                replica_port: replica[:port],
                remote_password: config[:password] == 'owned67_remote_password',
                supplied_key: app.secret_key_base == 'owned67_supplied_key_' * 4,
                remote_key: app.secret_key_base == 'owned67_remote_key_' * 4)
rescue StandardError => error
  result[:error_class] = error.class.name
  # Only our sanitized diagnostics may be emitted; SDK exception messages may contain secrets.
  result[:error] = error.message if (defined?(AwsBootstrap::Error) && error.is_a?(AwsBootstrap::Error)) || error.message.start_with?('owned67 ')
ensure
  requests = clients.flat_map(&:api_requests)
  result[:requests] = requests.group_by { |request| request[:operation_name] }.transform_values(&:length)
  result[:selected_database_id] = requests.any? { |request| request[:operation_name] == :get_secret_value && request[:params][:secret_id] == 'owned67/database' }
  result[:selectors_preserved] = ENV['AWS_REGION'] == 'us-west-2' && ENV['AWS_SSM_PATH'] == '/app/' &&
                                 ENV['AWS_EXPORT_CLOUDFRONT_ENDPOINT'] == 'assetDomainOwned67' &&
                                 ENV['AWS_DATABASE_SECRET_ID'] == 'owned67/database' &&
                                 ENV['AWS_SECRET_KEY_BASE_SECRET_ID'] == 'owned67/key'
  result[:ssm_paths_correct] = requests.select { |request| request[:operation_name] == :get_parameters_by_path }
                                       .all? { |request| request[:params][:path] == '/app/' }
  result[:regions_correct] = clients.all? { |client| client.config.region == 'us-west-2' }
  result[:driver_calls] = counters[:driver]
  result[:network_calls] = counters[:network]
  FileUtils.remove_entry(owned_tmp)
  result[:cleanup_complete] = !File.exist?(owned_tmp)
  # rubocop:disable-next RSpec/Output -- Structured output is the standalone CLI probe contract.
  puts "OWNED67_RESULT=#{JSON.generate(result)}"
end
exit(result[:error_class] ? 1 : 0)
