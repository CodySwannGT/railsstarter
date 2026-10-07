# frozen_string_literal: true

require 'bundler/setup'
require 'active_record'
require 'active_record/database_configurations'
require 'active_support/configuration_file'
require 'strong_migrations'
require 'mysql2'
require 'json'
require 'open3'

# Actual migrations, not Schema#define (which the checker deliberately exempts).
module MigrationSafetyFixtures
  TABLE = :owned77_widgets

  class CreateWidgets < ActiveRecord::Migration[8.1]
    def change
      create_table TABLE do |table|
        table.integer :a
        table.integer :b
        table.integer :c
        table.integer :d
      end
    end
  end

  class UnsafeIndex < ActiveRecord::Migration[8.1]
    def change
      add_index TABLE, %i[a b c d], name: 'owned77_unsafe_index'
    end
  end

  class SafeIndex < ActiveRecord::Migration[8.1]
    def change
      add_index TABLE, %i[d b], name: 'owned77_safe_index'
    end
  end

  class UniqueIndex < ActiveRecord::Migration[8.1]
    def change
      add_index TABLE, %i[a b c d], unique: true, name: 'owned77_unique_index'
    end
  end
end

# A caller supplies a receipt for a newly created, labelled disposable server.
# Names alone never authorize access: verify the daemon and physical identity.
class StrongMigrationsProbe
  MIGRATIONS = {
    'unsafe' => MigrationSafetyFixtures::UnsafeIndex,
    'safe' => MigrationSafetyFixtures::SafeIndex,
    'unique' => MigrationSafetyFixtures::UniqueIndex
  }.freeze

  attr_reader :result

  def initialize(scenario, mode)
    @scenario = scenario
    @mode = mode
    @result = { scenario: scenario, mode: mode, driver_connections: 0, index_ddl: [] }
  end

  def run
    refuse! unless MIGRATIONS.key?(@scenario) && %w[final baseline].include?(@mode)
    observe_driver
    native_preflight
    verify_owner
    verify_config
    create_owned_database
    migrate
  ensure
    cleanup
  end

  private

  def refuse!
    raise ArgumentError, 'owned77 migration probe refused unsafe input'
  end

  def observe_driver
    record = result
    Mysql2::Client.singleton_class.prepend(Module.new do
      define_method(:new) do |*args, **kwargs, &block|
        record[:driver_connections] += 1
        super(*args, **kwargs, &block)
      end
    end)
  end

  def native_preflight
    # Keep the native declaration and checks; stop before boot/maintenance.
    path = File.expand_path('../../rails_helper.rb', __dir__)
    source, boot_boundary = File.read(path).split("LisaTestIsolation.environment!\n", 2)
    refuse! unless boot_boundary && source.include?('module LisaTestIsolation')
    eval(source, TOPLEVEL_BINDING, path) # rubocop:disable Security/Eval -- Evaluate only the unchanged host-owned isolation declaration, never supplied input.
    LisaTestIsolation.environment!
    LisaTestIsolation.preflight!
    raw = ActiveSupport::ConfigurationFile.parse(File.expand_path('../../../config/database.yml', __dir__))
    shared = raw.delete('shared')
    @configurations = ActiveRecord::DatabaseConfigurations.new(LisaTestIsolation.merge_shared!(raw, shared))
    LisaTestIsolation.databases!(@configurations)
    @config = @configurations.configs_for(env_name: 'test', name: 'primary')
    result[:native_preaccess] = true
  end

  def verify_owner
    load_owner
    container = inspect_container
    verify_labels(container.fetch('Config').fetch('Labels'))
    verify_container_identity(container)
    verify_container_endpoint(container.fetch('NetworkSettings'))
    result[:daemon_owner_verified] = true
  end

  def load_owner
    @owner = JSON.parse(File.read(ENV.fetch('MIGRATION_PROBE_OWNERSHIP')))
    refuse! unless @owner.fetch('work_item') == 'CodySwannGT/railsstarter#77'
    token = @owner.fetch('token')
    refuse! unless token.match?(/\A[0-9a-f]{12}\z/)
    refuse! unless @owner.fetch('namespace_prefix') == "owned77_#{token}"
  end

  def inspect_container
    output, _, status = Open3.capture3(@owner.fetch('docker_executable', 'docker'), 'container', 'inspect', @owner.fetch('container_id'))
    refuse! unless status.success?

    JSON.parse(output).fetch(0)
  end

  def verify_labels(labels)
    expected = { 'lisa.owner_token' => @owner.fetch('token'), 'lisa.work_item' => @owner.fetch('work_item'),
                 'test.run_id' => @owner.fetch('test_run_id') }
    refuse! unless labels.slice(*expected.keys) == expected
  end

  def verify_container_identity(container)
    refuse! unless container['Id'] == @owner['container_id'] && container['Image'] == @owner.fetch('image_id') && container['State']['Running']
  end

  def verify_container_endpoint(settings)
    ports = settings.fetch('Ports').fetch('3306/tcp')
    refuse! unless ports == [{ 'HostIp' => '127.0.0.1', 'HostPort' => @owner.fetch('host_port').to_s }]
    refuse! unless settings.fetch('Networks').keys == [@owner.fetch('network_name')]
  end

  def verify_config
    config = @config.configuration_hash
    @database = @config.database
    refuse! unless @database.match?(/\A#{Regexp.escape(@owner.fetch('namespace_prefix'))}_[a-z0-9_]+_test\z/)
    verify_connection_options(config)
    refuse! if config[:aws_rds_iam_auth] || ENV.key?('SAFETY_ASSURED')
    result[:database] = @database
    result[:resolved_roles] = @configurations.configs_for(env_name: 'test', include_hidden: true).map { |db| [db.name, db.database] }
  end

  def verify_connection_options(config)
    actual = { host: config[:host], port: config[:port].to_i, username: config[:username], adapter: config[:adapter] }
    expected = { host: '127.0.0.1', port: @owner.fetch('host_port'), username: 'root', adapter: 'mysql2' }
    refuse! unless actual == expected && config[:password].to_s.empty?
  end

  def physical_identity
    @admin.query('SELECT VERSION() AS version, @@server_uuid AS uuid, @@hostname AS hostname').first
  end

  def verify_physical_identity
    identity = physical_identity
    refuse! unless identity == { 'version' => '8.4.11', 'uuid' => @owner.fetch('server_uuid'), 'hostname' => @owner.fetch('server_hostname') }
    result[:physical_identity] = identity
  end

  def create_owned_database
    @admin = Mysql2::Client.new(host: '127.0.0.1', port: @owner.fetch('host_port'), username: 'root')
    verify_physical_identity
    refuse! unless database_absent?
    @admin.query("CREATE DATABASE `#{@database}`")
    @created = true
    ActiveRecord::Base.configurations = @configurations
    ActiveRecord::Base.establish_connection(@config)
    refuse! unless ActiveRecord::Base.connection.select_value('SELECT DATABASE()') == @database
  end

  def snapshot
    connection = ActiveRecord::Base.connection
    { schema: connection.select_rows('SHOW CREATE TABLE owned77_widgets').first.last,
      indexes: connection.indexes(MigrationSafetyFixtures::TABLE).map { |index| { name: index.name, columns: index.columns, unique: index.unique } },
      rows: connection.select_rows('SELECT a, b, c, d FROM owned77_widgets ORDER BY id') }
  end

  def database_absent?
    @admin.query("SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = '#{@database}'").none?
  end

  def migrate
    load_defaults
    MigrationSafetyFixtures::CreateWidgets.new(nil, 20_261_005_000_076).migrate(:up)
    ActiveRecord::Base.connection.execute('INSERT INTO owned77_widgets (a,b,c,d) VALUES (1,2,3,4)')
    result[:before] = snapshot
    run_checked_index
    result[:after] = snapshot
    result[:schema_unchanged] = result[:before] == result[:after]
  end

  def load_defaults
    load File.expand_path('../../../config/initializers/strong_migrations.rb', __dir__)
    refuse! unless StrongMigrations::Checker.safe.nil? && StrongMigrations.start_after.zero? && StrongMigrations.skipped_databases.empty?
    result[:settings] = { check_enabled: StrongMigrations.check_enabled?(:add_index_columns), target_version: StrongMigrations.target_version,
                          safe_by_default: StrongMigrations.safe_by_default, safety_assured: false, direction: 'up', version: 20_261_005_000_077 }
  end

  def run_checked_index
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |event|
      sql = event.payload[:sql]
      result[:index_ddl] << sql if sql.match?(/(?:CREATE .*INDEX|ALTER TABLE .*ADD .*INDEX)/i)
    end
    begin
      MIGRATIONS.fetch(@scenario).new(nil, 20_261_005_000_077).migrate(:up)
    rescue StrongMigrations::UnsafeMigration => error
      result[:rejection] = { class: error.class.name, message: error.message }
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end

  def cleanup
    return unless @admin

    if @created
      verify_physical_identity
      ActiveRecord::Base.connection_pool.disconnect!
      @admin.query("DROP DATABASE `#{@database}`")
      result[:owned_database_absent] = database_absent?
      refuse! unless result[:owned_database_absent]
    end
    @admin.close
  end
end

probe = StrongMigrationsProbe.new(ARGV.fetch(0), ARGV.fetch(1, 'final'))
begin
  probe.run
  probe.result[:passed] = true
rescue StandardError, SystemExit => error
  probe.result[:passed] = false
  probe.result[:error_class] = error.class.name
  probe.result[:refused] = error.is_a?(ArgumentError) || error.is_a?(SystemExit)
ensure
  # rubocop:disable-next RSpec/Output -- Structured output is the standalone acceptance probe's contract.
  puts "OWNED77_MIGRATION_RESULT=#{JSON.generate(probe.result)}"
end
exit(probe.result[:passed] ? 0 : 1)
