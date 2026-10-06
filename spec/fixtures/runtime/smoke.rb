# frozen_string_literal: true

# Standalone runtime-only acceptance harness. Does not load rails_helper or reset
# databases. Database mode requires four already-created, empty MySQL databases
# on an explicitly isolated endpoint; their container/cleanup belongs to caller.
require 'json'
require 'digest'
require 'rbconfig'

# Boots the actual app with authored SDK responses and optional isolated schemas.
class DependencySmoke
  ROOT = File.expand_path('../../..', __dir__)
  FIXTURE = JSON.parse(File.read(File.join(__dir__, 'acceptance.json')))
  SCHEMAS = { 'primary' => 'schema', 'queue' => 'queue_schema',
              'cache' => 'cache_schema', 'cable' => 'cable_schema' }.freeze
  LOCAL_HOSTS = %w[127.0.0.1 host.docker.internal].freeze
  TABLES = { 'primary' => 'ar_internal_metadata', 'queue' => 'solid_queue_jobs',
             'cache' => 'solid_cache_entries', 'cable' => 'solid_cable_messages' }.freeze
  SUFFIXES = { 'primary' => 'test', 'primary_replica' => 'test', 'queue' => 'queue_test',
               'cache' => 'cache_test', 'cable' => 'cable_test' }.freeze

  class << self
    # @return [Hash] observed boot, request, dependency and optional schema evidence
    def run
      validate_environment!
      configure_environment
      configure_aws
      require File.join(ROOT, 'config/environment')
      Rails.application.eager_load!
      validate_authored_responses!

      runtime = native_runtime
      databases = database_mode? ? load_schemas : []
      { boot: Rails.env.to_s, image_mode: image_mode?, eager_load: true, versions: versions,
        runtime: runtime, requests: requests, aws_requests: aws_requests, databases: databases, aws: aws_evidence }
    end

    # @return [void]
    def validate_authored_responses!
      unless image_mode?
        raise 'Local runtime smoke made AWS requests' unless aws_requests.empty?
        raise 'Local runtime smoke consumed remote configuration' if ENV.key?('RUNTIME_SMOKE_FIXTURE') || ENV.key?('_RUNTIME_SMOKE_FIXTURE')

        return
      end

      raise 'Image smoke requires explicit stubbed bootstrap' unless ENV['AWS_BOOTSTRAP_ENABLED'] == 'true' && Aws.config[:stub_responses]
      raise 'Authored SSM fixture was not consumed' unless ENV['RUNTIME_SMOKE_FIXTURE'] == 'authored-local-only'

      expected_requests = { 'ssm.get_parameters_by_path' => 1, 'cloudformation.list_exports' => 1,
                            'secretsmanager.list_secrets' => 1, 'secretsmanager.get_secret_value' => 1 }
      raise 'Authored AWS requests were not consumed' unless aws_requests == expected_requests

      expected = FIXTURE.dig('aws', 'secretsmanager', 'get_secret_value', 'secret_string')
      raise 'Authored secret fixture was not consumed' unless Rails.application.secret_key_base == expected
    end

    # Reject unsafe inputs before Rails, initializers or a database client load.
    # @return [void]
    def validate_environment!
      validate_runtime_environment!
      raise 'Database URLs are forbidden' if ENV.keys.any? { |key| database_url?(key) && !ENV[key].to_s.empty? }

      validate_database_environment!
      validate_database_mode!
      validate_image_environment! if image_mode?
    end

    # @return [void]
    def validate_runtime_environment!
      raise 'Unknown image mode' unless %w[0 1].include?(ENV.fetch('RUNTIME_SMOKE_IMAGE', '0'))
      raise "RAILS_ENV must be #{runtime_environment}" unless ENV.fetch('RAILS_ENV', 'test') == runtime_environment
      raise "RACK_ENV must be #{runtime_environment}" unless ENV.fetch('RACK_ENV', 'test') == runtime_environment
    end

    # @return [void]
    def validate_database_mode!
      raise 'Unknown database mode' unless %w[0 1].include?(ENV.fetch('RUNTIME_SMOKE_DB', '0'))
      raise 'Database mode requires explicit isolation inputs' if database_mode? && missing_database_inputs?
    end

    # Production image proof requires the complete runtime bundle and isolation.
    # @return [void]
    def validate_image_environment!
      raise 'Runtime image smoke requires database mode' unless database_mode?
      raise 'Dummy secret flag forbidden' if ENV.key?('SECRET_KEY_BASE_DUMMY')
      raise 'Extra Rails groups forbidden' unless ENV.fetch('RAILS_GROUPS', '').empty?

      safe_bundle = ENV['BUNDLE_DEPLOYMENT'] == '1' && ENV['BUNDLE_PATH'] == '/usr/local/bundle' &&
                    ENV.fetch('BUNDLE_WITHOUT', '').split(':').sort == %w[development test]
      raise 'Production runtime bundle required' unless safe_bundle
    end

    # @return [void]
    def validate_database_environment!
      raise 'Unsafe database namespace' unless database_name.match?(/\Arailsstarter_63_smoke_[a-z0-9_]{1,24}\z/)
      raise 'Unsafe database host' unless LOCAL_HOSTS.include?(database_host)
      raise 'Unsafe replica host' unless ENV.fetch('DATABASE_REPLICA_HOST', database_host) == database_host
      raise 'Explicit isolated database port required' unless database_port.between?(1025, 65_535) && database_port != 3306
      raise 'Database IAM/SSL options forbidden' if %w[DATABASE_IAM_AUTH DATABASE_SSL].any? { |key| ENV[key] == 'true' }
    end

    # @return [void]
    def configure_environment
      ENV.keys.grep(/\A(?:AWS_|OTEL_|CLOUDFRONT_ENDPOINT\z|_?RUNTIME_SMOKE_FIXTURE\z)/).each { |key| ENV.delete(key) }
      ENV.update('RAILS_ENV' => runtime_environment, 'RACK_ENV' => runtime_environment, 'DATABASE_NAME' => database_name,
                 'PRIMARY_DB_HOST' => database_host, 'DATABASE_REPLICA_HOST' => database_host,
                 'DATABASE_PORT' => database_port.to_s, 'DATABASE_USER' => ENV.fetch('DATABASE_USER', 'runtime_smoke'),
                 'AWS_EC2_METADATA_DISABLED' => 'true', 'AWS_BOOTSTRAP_ENABLED' => image_mode? ? 'true' : 'false')
      ENV['REQUEST_INGRESS_PROFILE'] ||= 'direct'
      ENV['REQUEST_RATE_LIMIT_ENABLED'] = 'false' unless database_mode?
      return unless image_mode?

      ENV['AWS_SECRET_KEY_BASE_SECRET_ID'] = 'runtime-smoke/key'
      ENV.delete('SECRET_KEY_BASE')
    end

    # Global SDK stubbing prevents every AWS service client from sending requests.
    # @return [void]
    def configure_aws
      require 'aws-sdk-cloudformation'
      require 'aws-sdk-ssm'
      require 'aws-sdk-secretsmanager'
      @aws_requests = Hash.new(0)
      Aws.config.update(stub_responses: true, region: 'us-east-1',
                        credentials: Aws::Credentials.new('runtime-smoke', 'synthetic'))
      FIXTURE.fetch('aws').each do |service, responses|
        authored = JSON.parse(JSON.generate(responses), symbolize_names: true)
        authored[:list_secrets] = { secret_list: [{ name: 'runtime-smoke/key' }] } if service == 'secretsmanager'
        Aws.config[service.to_sym] = { stub_responses: authored.transform_keys(&:to_sym).to_h do |operation, response|
          [operation, lambda do |_context|
            @aws_requests["#{service}.#{operation}"] += 1
            response
          end]
        end }
      end
    end

    # @return [Hash{String => Integer}] actual SDK operation counts, without response values
    def aws_requests = @aws_requests.to_h

    # @return [Hash] actual SDK callback observations without response values
    def aws_evidence
      requests = aws_requests.flat_map do |identity, count|
        service, operation = identity.split('.', 2)
        Array.new(count) { { service: service, operation: operation } }
      end
      { bootstrap_enabled: ENV.fetch('AWS_BOOTSTRAP_ENABLED'), stub_responses: Aws.config[:stub_responses],
        requests: requests, fixture_consumed: ENV.fetch('RUNTIME_SMOKE_FIXTURE', nil) }
    end

    # @return [Hash{String => String}] loaded versions, enforcing patched floors
    def versions
      FIXTURE.fetch('minimum_versions').to_h do |name, minimum|
        spec = Gem.loaded_specs[name]
        next [name, 'absent from runtime bundle'] if name == 'rubyzip' && !spec

        raise "Missing runtime gem #{name}" unless spec
        raise "Unpatched runtime gem #{name}: #{spec.version}" if spec.version < Gem::Version.new(minimum)

        [name, spec.version.to_s]
      end
    end

    # Observe the interpreter and loaded native binaries in the actual booted app.
    # @return [Hash] Ruby identity and native-extension content identities
    def native_runtime
      expected = File.read(File.join(ROOT, '.ruby-version')).strip
      raise "Ruby runtime mismatch: observed #{RUBY_VERSION}, declared #{expected}" unless expected == RUBY_VERSION

      selected = FIXTURE.fetch('ruby_runtime')
      valid_ruby = selected.fetch('version') == RUBY_VERSION && selected.fetch('patchlevel') == RUBY_PATCHLEVEL
      raise 'Ruby runtime differs from verified release fixture' unless valid_ruby

      require 'mysql2'
      require 'bootsnap/bootsnap'
      extensions = %w[mysql2 bootsnap].to_h do |name|
        path = $".find { |feature| feature.match?(%r{/#{name}/#{name}\.(?:so|bundle)\z}) }
        raise "Native extension not loaded: #{name}" unless path

        [name, { version: Gem.loaded_specs.fetch(name).version.to_s, path: path,
                 sha256: Digest::SHA256.file(path).hexdigest }]
      end
      { ruby: RUBY_VERSION, patchlevel: RUBY_PATCHLEVEL, platform: RUBY_PLATFORM,
        executable: RbConfig.ruby, extensions: extensions }
    end

    # @return [Array<Hash>] actual Rack response observations
    def requests
      require 'rack/mock'
      FIXTURE.fetch('requests').map do |expected|
        path = expected.fetch('path')
        response = Rack::MockRequest.new(Rails.application).get(image_mode? ? "https://example.org#{path}" : path,
                                                                'HTTP_HOST' => 'example.org', 'REMOTE_ADDR' => '127.0.0.1')
        validate_response!(response, expected)

        { path: expected.fetch('path'), status: response.status, content_type: response.content_type,
          body: expected.fetch('body'), body_sha256: Digest::SHA256.hexdigest(response.body) }
      end
    end

    # @param response [Rack::MockResponse]
    # @param expected [Hash]
    # @return [void]
    def validate_response!(response, expected)
      raise "Unexpected response for #{expected.fetch('path')}: #{response.status}" unless response.status == expected.fetch('status')
      raise 'Unexpected response content type' unless response.content_type.start_with?(expected.fetch('content_type'))
      raise 'Expected response body missing' unless response.body.include?(expected.fetch('body'))
    end

    # Validate every resolved endpoint and schema's freshness BEFORE any schema load.
    # @return [Array<Hash>] schema identity and actual read results for all four DBs
    def load_schemas
      configs = ActiveRecord::Base.configurations.configs_for(env_name: runtime_environment, include_hidden: true)
      raise 'Unexpected database configuration inventory' unless configs.map(&:name).sort == (SCHEMAS.keys + ['primary_replica']).sort

      configs.each { |config| validate_config!(config) }
      configs = configs.reject(&:replica?)
      configs.each do |config|
        with_connection(config) { |connection| validate_fresh_database!(connection, config) }
      end
      configs.map { |config| load_schema(config) }
    end

    # @param config [ActiveRecord::DatabaseConfigurations::HashConfig]
    # @return [void]
    def validate_config!(config)
      settings = config.configuration_hash
      expected_name = expected_database_name(config.name)
      safe = config.database == expected_name && settings[:adapter] == 'mysql2' &&
             settings[:host] == database_host && settings[:port].to_i == database_port && !settings[:socket] &&
             !settings[:aws_rds_iam_auth] && !settings[:url]
      raise "Unsafe resolved database config: #{config.name}" unless safe
    end

    # @param connection [ActiveRecord::ConnectionAdapters::Mysql2Adapter]
    # @param config [ActiveRecord::DatabaseConfigurations::HashConfig]
    # @return [void]
    def validate_fresh_database!(connection, config)
      raise 'MySQL 8.4 required' unless connection.select_value('SELECT VERSION()').start_with?('8.4.')
      raise 'Connected database identity mismatch' unless connection.select_value('SELECT DATABASE()') == config.database
      raise "Database is not empty: #{config.database}" unless connection.tables.empty?
    end

    # @param config [ActiveRecord::DatabaseConfigurations::HashConfig]
    # @return [Hash] schema hash and a real read through the patched adapter
    def load_schema(config)
      file = File.join(ROOT, "db/#{SCHEMAS.fetch(config.name)}.rb")
      tasks = ActiveRecord::Tasks::DatabaseTasks
      tasks.send(:with_temporary_pool, config) { tasks.load_schema(config, :ruby, file) }
      with_connection(config) do |connection|
        table = TABLES.fetch(config.name)
        { name: config.database, host: database_host, port: database_port,
          schema_sha256: Digest::SHA256.file(file).hexdigest,
          table: table, rows: connection.select_value("SELECT COUNT(*) FROM #{connection.quote_table_name(table)}") }
      end
    end

    # @param config [ActiveRecord::DatabaseConfigurations::HashConfig]
    # @yield [connection] a temporary pool, restored after the bounded operation
    # @return [Object]
    def with_connection(config, &)
      ActiveRecord::Tasks::DatabaseTasks.send(:with_temporary_pool, config) { |pool| pool.with_connection(&) }
    end

    # @return [Boolean]
    def database_mode? = ENV.fetch('RUNTIME_SMOKE_DB', '0') == '1'

    # @return [Boolean]
    def image_mode? = ENV.fetch('RUNTIME_SMOKE_IMAGE', '0') == '1'

    # @return [String]
    def runtime_environment = image_mode? ? 'production' : 'test'

    # @param name [String] resolved database configuration name
    # @return [String] exact isolated database name for the selected environment
    def expected_database_name(name)
      return "#{database_name}_#{SUFFIXES.fetch(name)}" unless image_mode?

      %w[primary primary_replica].include?(name) ? database_name : "#{database_name}_#{name}"
    end

    # @return [String]
    def database_name = ENV.fetch('DATABASE_NAME', 'railsstarter_63_smoke_boot')

    # @return [String]
    def database_host = ENV.fetch('PRIMARY_DB_HOST', '127.0.0.1')

    # @return [Integer]
    def database_port = Integer(ENV.fetch('DATABASE_PORT', '13363'), 10)

    # @param key [String]
    # @return [Boolean]
    def database_url?(key) = key == 'DATABASE_URL' || key.end_with?('_DATABASE_URL')

    # @return [Boolean]
    def missing_database_inputs?
      %w[DATABASE_NAME PRIMARY_DB_HOST DATABASE_PORT DATABASE_USER DATABASE_PASSWORD].any? { |key| !ENV.key?(key) }
    end
  end
end

if $0 == __FILE__
  begin
    JSON.dump({ runtime_smoke_result: DependencySmoke.run }, $stdout)
  rescue StandardError => error
    warn "RUNTIME_SMOKE_FAILURE=#{error.class}: #{error.message}"
    exit 1
  end
end
