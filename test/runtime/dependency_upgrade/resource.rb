# frozen_string_literal: true

require 'json'
require 'pathname'
require 'active_record'
require 'active_record/database_configurations'
require 'active_support/configuration_file'

# Validate rendered configuration including hidden replicas before any adapter.
module DependencyResource
  ROOT = File.expand_path('../../..', __dir__)
  PASSWORD = 'synthetic-80-owned-only'
  ROLES = %w[primary primary_replica queue cable cache].freeze

  module_function

  # @return [Hash] generated owned-resource identity, never an ambient endpoint
  def validate!
    validate_environment!
    resource = read_resource!
    raw = ActiveSupport::ConfigurationFile.parse(File.join(ROOT, 'config/database.yml'))
    configs = ActiveRecord::DatabaseConfigurations.new(raw).configs_for(env_name: resource.fetch('environment'), include_hidden: true)
    raise 'Role inventory changed' unless configs.map(&:name).sort == ROLES.sort

    configs.each { |config| validate_role!(config, resource) }
    resource.merge('configs' => configs)
  end

  # @return [void] unsafe URLs and hidden role overrides never reach an adapter
  def validate_environment!
    expected = ENV.fetch('DEPENDENCY80_ENVIRONMENT', 'test')
    safe = %w[test development].include?(expected) && ENV.values_at('RAILS_ENV', 'RACK_ENV') == [expected, expected]
    raise 'Both environments must match the explicit owned fixture mode' unless safe

    forbidden = ENV.keys.any? do |key|
      key.end_with?('DATABASE_URL', '_DB_URL') || (key.start_with?('OTEL_', '_') && key != '__CF_USER_TEXT_ENCODING')
    end
    raise 'URL/hidden/telemetry input forbidden' if forbidden
  end

  # @return [Hash] physical identity recorded by this invocation's Docker owner
  def read_resource!
    path = File.realpath(ENV.fetch('DEPENDENCY80_RESOURCE'))
    resource = JSON.parse(File.read(path))
    scratch = resource.fetch('scratch')
    nonce = resource.fetch('nonce')
    owned = File.dirname(path) == scratch && File.dirname(scratch) == File.join(ROOT, 'tmp') &&
            File.basename(scratch).start_with?("railsstarter80-#{nonce}-") && nonce.match?(/\A[a-f0-9]{12}\z/)
    raise 'Unowned resource receipt' unless owned
    raise 'Resource environment mismatch' unless resource['environment'] == ENV.fetch('DEPENDENCY80_ENVIRONMENT', 'test')

    validate_endpoint!(resource)

    resource
  end

  # @param resource [Hash] expected Docker-owned endpoint
  # @return [void] prevent ambient default-port or nonloopback connections
  def validate_endpoint!(resource)
    safe = resource['host'] == '127.0.0.1' && resource['port'].between?(1025, 65_535) && resource['port'] != 3306
    raise 'Unsafe owned endpoint' unless safe
  end

  # @param config [ActiveRecord::DatabaseConfigurations::HashConfig] rendered role
  # @param resource [Hash] generated caller-owned physical identity
  # @return [void] all resolved options checked before opening a connection
  def validate_role!(config, resource)
    settings = config.configuration_hash
    role = config.name == 'primary_replica' ? 'primary' : config.name
    expected = resource.fetch('databases').fetch(role)
    safe = config.database == expected && expected.match?(/(?:\A|[_-])test(?:\z|[_-])/) &&
           settings.values_at(:adapter, :host, :username, :password) == ['mysql2', '127.0.0.1', 'dependency80', PASSWORD] &&
           settings[:port].to_i == resource.fetch('port') &&
           indirect_options_absent?(settings)
    raise "Unsafe rendered role: #{config.name}" unless safe
  end

  # @param settings [Hash] rendered connection options
  # @return [Boolean] no remote URL, socket, SSL or IAM credential route
  def indirect_options_absent?(settings)
    settings.values_at(:url, :socket, :ssl_mode, :aws_rds_iam_auth).none?
  end

  # @param resource [Hash] validated configurations
  # @return [Array<Hash>] exact server UUID/database/grants before app boot
  def physical!(resource)
    resource.fetch('configs').map do |config|
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        inspect_connection(connection, config, resource)
      end
    end
  ensure
    ActiveRecord::Base.connection_handler.clear_all_connections!
  end

  # @param connection [ActiveRecord::ConnectionAdapters::Mysql2Adapter] owned user
  # @param config [ActiveRecord::DatabaseConfigurations::HashConfig] resolved role
  # @param resource [Hash] exact expected schema and physical server
  # @return [Hash] authenticated identity and table inventory
  def inspect_connection(connection, config, resource)
    identity = connection.select_rows('SELECT VERSION(),@@server_uuid,@@hostname,@@port').first.map(&:to_s)
    raise 'MySQL physical identity mismatch' unless identity == resource.fetch('identity')
    raise 'Schema identity mismatch' unless connection.select_value('SELECT DATABASE()') == config.database
    raise 'Schema grants mismatch' unless connection.select_values('SHOW GRANTS').sort == resource.fetch('grants').sort

    { role: config.name, database: config.database, identity: identity, tables: connection.tables.sort }
  end
end
