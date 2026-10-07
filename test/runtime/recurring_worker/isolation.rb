# frozen_string_literal: true

# Synthetic resource validation and owned-schema preparation for the acceptance fixture.
module RecurringWorkerIsolation
  ROOT = File.expand_path('../../..', __dir__)
  SCHEMAS = { 'primary' => 'schema', 'queue' => 'queue_schema', 'cache' => 'cache_schema', 'cable' => 'cable_schema' }.freeze
  MODES = %w[normal omit-command omit-class command-failure sdk-failure].freeze

  # Reject all unsafe inputs before loading Rails or any database adapter.
  # @return [void]
  def validate_environment!
    raise 'Unknown acceptance mode' unless MODES.include?(@mode)

    validate_scratch!
    raise 'Private output directory required' unless File.dirname(@output) == @directory
    raise 'Both Rails and Rack must be test' unless ENV['RAILS_ENV'] == 'test' && ENV['RACK_ENV'] == 'test'
    raise 'URL, hidden-role or endpoint inputs forbidden' if ENV.keys.any? { |key| key != '__CF_USER_TEXT_ENCODING' && key.match?(/DATABASE_URL|_DB_URL|\A_|\AOTEL_/) }
    raise 'Extra runtime flags forbidden' if %w[RAILS_GROUPS SECRET_KEY_BASE_DUMMY AWS_PROFILE AWS_SESSION_TOKEN].any? { |key| ENV.key?(key) }

    validate_resource!
    validate_synthetic_inputs!
    record_sources
  end

  # @return [void] explicit caller-owned physical resource metadata
  def validate_resource!
    @resource = JSON.parse(File.read(ENV.fetch('RECURRING_RESOURCE')))
    @databases = @resource.fetch('databases')
    validate_resource_scratch!

    safe = valid_endpoint? && @resource['database_prefix'].match?(/\Arailsstarter66_[a-f0-9]{12}\z/) &&
           @databases.keys.sort == SCHEMAS.keys.sort && @databases.values.uniq.size == 4 &&
           @databases.values.all? { |name| name.start_with?("#{@resource['database_prefix']}_") && name.end_with?('_test') }
    raise 'Invalid owned resource' unless safe
  end

  # @return [Boolean] explicit unique loopback port
  def valid_endpoint?
    @resource['host'] == '127.0.0.1' && @resource['port'].between?(1025, 65_535) && @resource['port'] != 3306
  end

  # @return [void] synthetic environment must match exact owned resource
  def validate_synthetic_inputs!
    expected = { 'DATABASE_NAME' => @resource['database_prefix'], 'PRIMARY_DB_HOST' => '127.0.0.1',
                 'DATABASE_REPLICA_HOST' => '127.0.0.1', 'DATABASE_PORT' => @resource['port'].to_s,
                 'DATABASE_USER' => 'root', 'DATABASE_PASSWORD' => @resource['synthetic_password'],
                 'DATABASE_SSL' => 'false', 'DATABASE_IAM_AUTH' => 'false', 'AWS_EC2_METADATA_DISABLED' => 'true',
                 'AWS_ACCESS_KEY_ID' => 'synthetic-66', 'AWS_SECRET_ACCESS_KEY' => 'synthetic-66', 'AWS_REGION' => 'us-east-1' }
    raise 'Sanitized runner environment required' unless expected.all? { |key, value| ENV[key] == value }
  end

  # @return [void] current source identity before runtime
  def record_sources
    @validated = true
    @result[:resource] = @resource.slice('container_id', 'image_id', 'host', 'port', 'server_identity', 'databases')
    paths = %w[config/queue.yml config/recurring.yml app/jobs/publish_cloud_watch_metrics_job.rb app/services/cloud_watch_service.rb
               test/runtime/recurring_worker/run.rb test/runtime/recurring_worker/isolation.rb test/runtime/recurring_worker/runner.py
               bin/test-recurring-worker
               spec/rails_helper.rb Gemfile Gemfile.lock]
    @result[:source_hashes] = {}
    paths.each { |path| @result[:source_hashes][path] = Digest::SHA256.file(File.join(ROOT, path)).hexdigest }
  end

  # Validate ALL resolved roles and freshness before the first schema load.
  # Subsequent runs only read the same caller-owned schema inventory, never reset.
  # @return [void]
  def prepare_owned_schemas
    configs = ActiveRecord::Base.configurations.configs_for(env_name: 'test', include_hidden: true)
    raise 'Unexpected role inventory' unless configs.map(&:name).sort == (SCHEMAS.keys + ['primary_replica']).sort

    configs.each { |config| validate_role!(config) }
    @result[:resolved_roles] = configs.map { |config| { name: config.name, database: config.database, replica: config.replica? } }
    configs = configs.reject(&:replica?)
    inspect_schemas(configs)
    initialize_schemas(configs) unless @prior
    @result[:databases] = { schema_hashes: @hashes, tables: @inventories, initialized_now: !@prior }
  end

  # @param configs [Array] fully validated resolved roles
  # @return [void] freshness/readback for ALL roles precedes any schema load
  def inspect_schemas(configs)
    @marker = File.join(@directory, 'reproduction-schema-ownership.json')
    @prior = File.exist?(@marker) ? JSON.parse(File.read(@marker)) : nil
    @hashes = SCHEMAS.transform_values { |schema| Digest::SHA256.file(File.join(ROOT, "db/#{schema}.rb")).hexdigest }
    raise 'Owned schema marker mismatch' if @prior && (@prior['resource'] != schema_resource_identity || @prior['hashes'] != @hashes)

    @inventories = configs.to_h { |config| [config.name, inspect_database(config)] }
  end

  # @param config [ActiveRecord::DatabaseConfigurations::HashConfig] validated owned role
  # @return [Array<String>] actual authenticated table inventory
  def inspect_database(config)
    with_connection(config) do |connection|
      identity = connection.select_rows('SELECT VERSION(),@@server_uuid,@@hostname,@@port').first.join("\t")
      raise 'Physical MySQL identity mismatch' unless identity == @resource['server_identity']
      raise 'Database identity mismatch' unless connection.select_value('SELECT DATABASE()') == config.database

      tables = connection.tables.sort
      raise "Database not fresh: #{config.database}" if !@prior && tables.any?
      raise 'Owned table inventory mismatch' if @prior && tables != @prior['tables'].fetch(config.name)

      tables
    end
  end

  # @param configs [Array] all roles proved fresh on caller-owned server
  # @return [void] load schemas once and record immutable ownership
  def initialize_schemas(configs)
    configs.each do |config|
      tasks = ActiveRecord::Tasks::DatabaseTasks
      file = File.join(ROOT, "db/#{SCHEMAS.fetch(config.name)}.rb")
      tasks.send(:with_temporary_pool, config) { tasks.load_schema(config, :ruby, file) }
      @inventories[config.name] = with_connection(config) { |connection| connection.tables.sort }
    end
    File.write(@marker, JSON.pretty_generate(resource: schema_resource_identity, hashes: @hashes, tables: @inventories))
  end

  # @param config [ActiveRecord::DatabaseConfigurations::HashConfig] resolved role
  # @return [void] validate every resolved URL and hidden replica before adapters
  def validate_role!(config)
    settings = config.configuration_hash
    name = config.name == 'primary_replica' ? 'primary' : config.name
    safe = safe_adapter_options?(settings) && config.database == @databases.fetch(name) && settings[:adapter] == 'mysql2' &&
           settings[:host] == '127.0.0.1' && settings[:port].to_i == @resource['port'] &&
           settings[:username] == 'root' && settings[:password] == @resource['synthetic_password']
    raise "Unsafe resolved role #{config.name}" unless safe
  end

  # @param settings [Hash] fully resolved adapter options
  # @return [Boolean] no indirect URL, socket or remote authentication inputs
  def safe_adapter_options?(settings)
    !settings[:socket] && !settings[:url] && !settings[:aws_rds_iam_auth] && !settings[:ssl_mode]
  end

  # @param config [ActiveRecord::DatabaseConfigurations::HashConfig] proved owned role
  # @yield [connection] temporary adapter connection
  # @return [Object] block result
  def with_connection(config, &)
    ActiveRecord::Tasks::DatabaseTasks.send(:with_temporary_pool, config) { |pool| pool.with_connection(&) }
  end
end

# Private scratch ownership shared by the standalone resource harness.
module RecurringWorkerScratch
  # @return [void] unique generated scratch ownership before Rails or adapters
  def validate_scratch!
    directory = File.realpath(@directory)
    owner = JSON.parse(File.read(File.join(directory, '.owner.json')))
    valid = directory == @directory && File.dirname(directory) == File.join(RecurringWorkerIsolation::ROOT, 'tmp') &&
            File.basename(directory).start_with?("recurring-worker-#{owner.fetch('nonce')}-") &&
            owner.fetch('root') == RecurringWorkerIsolation::ROOT && !File.symlink?(@output)
    raise 'Invalid owned scratch directory' unless valid
  end

  # @return [Hash] exact physical and logical schema ownership across five cases
  def schema_resource_identity
    @resource.slice('nonce', 'container_id', 'server_identity', 'databases')
  end

  # @return [void] resource and generated private scratch must share exact nonce
  def validate_resource_scratch!
    owner = JSON.parse(File.read(File.join(@directory, '.owner.json')))
    raise 'Resource scratch ownership mismatch' unless owner['nonce'] == @resource['nonce'] && @resource['scratch_directory'] == @directory
  end
end

# Standard SDK response callbacks distinguish inert boot from real job publication.
module RecurringWorkerAws
  # @return [void] every relevant SDK operation remains stubbed and recorded
  def configure_aws
    %w[cloudformation ssm cloudwatch secretsmanager].each { |service| require "aws-sdk-#{service}" }
    Aws.config.update(stub_responses: true)
    configure_boot_stubs
    Aws.config[:cloudwatch] = { stub_responses: { put_metric_data: lambda { |context|
      record_call('put_metric_data', context.params, @mode != 'sdk-failure')
      @mode == 'sdk-failure' ? Aws::CloudWatch::Errors::ServiceError.new(context, '66 controlled SDK failure') : {}
    } } }
  end

  # @return [void] consumed bootstrap calls invalidate the zero-AWS boot witness
  def configure_boot_stubs
    operations = { cloudformation: [:list_exports, { exports: [] }],
                   ssm: [:get_parameters_by_path, { parameters: [] }],
                   secretsmanager: [:get_secret_value, { secret_string: '{}' }] }
    operations.each do |service, (operation, response)|
      Aws.config[service] = { stub_responses: { operation => lambda { |context|
        record_call(operation.to_s, context.params, true)
        response
      } } }
    end
  end
end
