# frozen_string_literal: true

# Standalone, explicit witness: bundle exec ruby test/runtime/utf8mb4_spec.rb
# It never boots Rails or uses the application's databases, helpers or AWS loaders.
require 'bundler/setup'
require 'active_record'
require 'active_record/tasks/database_tasks'
require 'active_record/tasks/mysql_database_tasks'
require 'digest'
require 'erb'
require 'json'
require 'mysql2'
require 'open3'
require 'rspec/core'
require 'rspec/expectations'
require 'securerandom'
require 'yaml'

# Each invocation owns a fresh container, volume and four strictly test databases.
class UnicodeDatabaseWitness
  ROOT = File.expand_path('../..', __dir__)
  SCHEMAS = { 'primary' => 'schema', 'queue' => 'queue_schema', 'cache' => 'cache_schema', 'cable' => 'cable_schema' }.freeze
  CHARSET = 'utf8mb4'
  COLLATION = 'utf8mb4_0900_ai_ci'
  SAMPLE = "Unicode café 漢字 😀 🧪 e\u0301"
  SYSTEM_DATABASES = %w[information_schema mysql performance_schema sys].freeze

  attr_reader :results, :baseline

  def initialize
    @token = SecureRandom.hex(8)
    @name = "unicode-witness-#{@token}"
    @prefix = "unicode_#{@token}"
    @password = SecureRandom.hex(32)
    @results = {}
  end

  def run
    manifest
    create_target
    prepare_databases
    SCHEMAS.each_key { |role| observe(role) }
  ensure
    cleanup
  end

  private

  def docker(*arguments, environment: {})
    output, error, status = Open3.capture3(environment, 'docker', *arguments)
    raise "Docker #{arguments.first} failed: #{error}" unless status.success?

    output.strip
  end

  def record(event, data)
    # The explicit CLI witness emits empirical artifacts rather than application logs.
    puts JSON.generate({ event: event, data: data }) # rubocop:disable RSpec/Output -- emits the empirical CLI receipt
  end

  def manifest
    paths = ['config/database.yml', *SCHEMAS.values.map { |schema| "db/#{schema}.rb" }, 'spec/database/utf8mb4_spec.rb', 'test/runtime/utf8mb4_spec.rb', 'docs/mysql-utf8mb4.md']
    record('source_manifest', paths.index_with { |path| Digest::SHA256.file(File.join(ROOT, path)).hexdigest })
    record('client_versions', ruby: RUBY_VERSION, active_record: ActiveRecord::VERSION::STRING, mysql2: Mysql2::VERSION)
  end

  def create_target
    @image = docker('image', 'inspect', 'mysql:8.4', '--format', '{{.Id}}')
    @volume = docker('volume', 'create', '--label', "unicode-witness=#{@token}")
    verify_volume
    create_container
    inspect_target
    docker('start', @id)
    inspect_target
    verify_started_target
    connect_server
  end

  def verify_started_target
    ports = JSON.parse(docker('inspect', @id)).fetch(0).fetch('NetworkSettings').fetch('Ports').fetch('3306/tcp')
    raise 'Unexpected mapped target' unless ports.one? && ports.first.fetch('HostIp') == '127.0.0.1'

    @port = Integer(ports.first.fetch('HostPort'))
    raise 'Volume empty preflight missing' unless docker('logs', @id).include?('EMPTY_VOLUME_OK')

    record('empty_volume_preflight', verified: true, volume: @volume)
  end

  def verify_volume
    volume = JSON.parse(docker('volume', 'inspect', @volume)).fetch(0)
    raise 'Unowned volume' unless volume.fetch('Labels').fetch('unicode-witness') == @token
  end

  def create_container
    gate = 'test -z "$(ls -A /var/lib/mysql)" || exit 99; echo EMPTY_VOLUME_OK; exec docker-entrypoint.sh mysqld'
    @id = docker('create', '--name', @name, '--label', "unicode-witness=#{@token}",
                 '--env', 'MYSQL_ROOT_PASSWORD', '--env', 'MYSQL_ROOT_HOST=%',
                 '--publish', '127.0.0.1::3306', '--mount', "type=volume,source=#{@volume},target=/var/lib/mysql",
                 '--entrypoint', 'sh', @image, '-c', gate, environment: { 'MYSQL_ROOT_PASSWORD' => @password })
  end

  def connect_server
    @admin = wait_for_server
    record('server', @admin.query('SELECT VERSION() AS version, @@server_uuid AS uuid').first)
    raise 'Expected actual MySQL 8.4' unless @admin.server_info.fetch(:version).start_with?('8.4.')

    databases = @admin.query('SHOW DATABASES').map { |row| row.fetch('Database') }
    raise 'Target has existing user databases' unless (databases - SYSTEM_DATABASES).empty?

    record('empty_target', databases: databases, container: @id, image: @image, port: @port, volume: @volume)
  end

  def inspect_target
    target = JSON.parse(docker('inspect', @id)).fetch(0)
    raise 'Container identity mismatch' unless target.fetch('Id') == @id && target.fetch('Image') == @image
    raise 'Container ownership mismatch' unless target.fetch('Config').fetch('Labels').fetch('unicode-witness') == @token

    verify_mount_and_binding(target)
    record('target_ownership', container: @id, label: @token, image: @image, mounts: target.fetch('Mounts'), host: '127.0.0.1')
  end

  def verify_mount_and_binding(target)
    mounts = target.fetch('Mounts')
    raise 'Unexpected database mount' unless mounts.one? && mounts.first.values_at('Name', 'Destination') == [@volume, '/var/lib/mysql']

    bindings = target.fetch('HostConfig').fetch('PortBindings').fetch('3306/tcp')
    raise 'Non-loopback publication' unless bindings.one? && bindings.first.fetch('HostIp') == '127.0.0.1'
  end

  def wait_for_server
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 90
    loop do
      return Mysql2::Client.new(host: '127.0.0.1', port: @port, username: 'root', password: @password, encoding: CHARSET)
    rescue Mysql2::Error
      raise 'Owned MySQL target did not become ready' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 1
    end
  end

  def configurations
    replacements = { 'RAILS_ENV' => 'test', 'DATABASE_NAME' => @prefix, 'PRIMARY_DB_HOST' => '127.0.0.1',
                     'DATABASE_USER' => 'root', 'DATABASE_PASSWORD' => @password, 'DATABASE_PORT' => @port.to_s,
                     'DATABASE_SSL' => 'false', 'DATABASE_IAM_AUTH' => 'false' }
    original = replacements.keys.index_with { |key| ENV.fetch(key, nil) }
    ENV.update(replacements)
    YAML.safe_load(ERB.new(File.read(File.join(ROOT, 'config/database.yml'))).result, aliases: true).fetch('test')
  ensure
    original&.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def prepare_databases
    @configs = configurations.slice(*SCHEMAS.keys)
    @configs.each { |role, config| verify_configuration(role, config) }
    raise 'Expected four unique databases' unless @configs.keys.sort == SCHEMAS.keys.sort && @configs.values.pluck('database').uniq.length == 4

    @configs.each { |role, config| create_owned_database(role, config) }
  end

  def create_owned_database(role, config)
    db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new('test', role, config)
    raise 'Wrong configuration environment' unless db_config.env_name == 'test'

    ActiveRecord::Tasks::MySQLDatabaseTasks.new(db_config).create
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      raise 'Database not empty before schema load' unless connection.tables.empty?

      record('empty_database', role: role, database: config.fetch('database'), tables: connection.tables)
      load File.join(ROOT, "db/#{SCHEMAS.fetch(role)}.rb")
    end
    ActiveRecord::Base.connection_pool.disconnect!
  end

  def verify_configuration(role, config)
    expected = role == 'primary' ? "#{@prefix}_test" : "#{@prefix}_#{role}_test"
    raise 'Unsafe witness configuration' unless config.values_at('database', 'host') == [expected, '127.0.0.1'] && Integer(config.fetch('port')) == @port
    raise 'Not a unique test database' unless expected.match?(/\Aunicode_[0-9a-f]{16}(?:_queue|_cache|_cable)?_test\z/)
  end

  def observe(role)
    ActiveRecord::Base.establish_connection(@configs.fetch(role))
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.create_table(:unicode_witness, temporary: true, charset: CHARSET, collation: COLLATION) { |table| table.string :value }
      original_failure(connection) if role == 'primary'
      @results[role] = collect_observations(connection)
      record('database_witness', { role: role, **@results.fetch(role) })
    end
  ensure
    ActiveRecord::Base.connection_pool.disconnect!
  end

  def collect_observations(connection)
    settings = connection.select_one(<<~SQL.squish)
      SELECT @@character_set_client AS client, @@character_set_connection AS connection,
             @@character_set_results AS results, @@collation_connection AS collation
    SQL
    database = connection.select_one('SELECT @@character_set_database AS charset, @@collation_database AS collation')
    tables = connection.select_all('SELECT TABLE_NAME, TABLE_COLLATION FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() ORDER BY TABLE_NAME').to_a
    columns = connection.select_all(<<~SQL.squish).to_a
      SELECT TABLE_NAME, COLUMN_NAME, CHARACTER_SET_NAME, COLLATION_NAME
      FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND CHARACTER_SET_NAME IS NOT NULL
      ORDER BY TABLE_NAME, ORDINAL_POSITION
    SQL
    { settings: settings, database: database, tables: tables, columns: columns, round_trip: write_and_read(connection),
      witness_column: connection.select_all('SHOW FULL COLUMNS FROM unicode_witness').to_a,
      witness_table: connection.select_one('SHOW CREATE TABLE unicode_witness').fetch('Create Table') }
  end

  def original_failure(connection)
    connection.execute('SET NAMES utf8')
    begin
      connection.execute("INSERT INTO unicode_witness (value) VALUES (#{connection.quote(SAMPLE)})")
      raise 'Original utf8 connection unexpectedly accepted emoji'
    rescue ActiveRecord::StatementInvalid => error
      @baseline = { error_class: error.cause.class.name, error_number: error.cause.error_number,
                    message: error.cause.message, settings: connection.select_one('SELECT @@character_set_connection AS charset, @@collation_connection AS collation') }
      record('original_utf8_rejection', @baseline)
    ensure
      config = @configs.fetch('primary')
      connection.execute("SET NAMES #{config.fetch('encoding')}#{" COLLATE #{config['collation']}" if config['collation']}")
    end
  end

  def write_and_read(connection)
    connection.execute("INSERT INTO unicode_witness (value) VALUES (#{connection.quote(SAMPLE)})")
    actual = connection.select_value('SELECT value FROM unicode_witness')
    { value: actual, bytes: actual.bytes, exact: actual == SAMPLE && actual.bytes == SAMPLE.bytes }
  rescue ActiveRecord::StatementInvalid => error
    { exact: false, error_number: error.cause.error_number, message: error.cause.message }
  end

  def cleanup
    ActiveRecord::Base.connection_handler.clear_all_connections!
    @admin&.close
    if @id
      inspect_target
      docker('rm', '--force', @id)
    end
    if @volume
      verify_volume
      docker('volume', 'rm', @volume)
    end
    containers = docker('ps', '--all', '--quiet', '--filter', "label=unicode-witness=#{@token}")
    volumes = docker('volume', 'ls', '--quiet', '--filter', "label=unicode-witness=#{@token}")
    raise 'Owned resources remain' unless containers.empty? && volumes.empty?

    record('cleanup', container_absent: true, volume_absent: true)
  end
end

# This file is a standalone CLI witness, with a descriptive path for operators.
RSpec.describe UnicodeDatabaseWitness do # rubocop:disable RSpec/SpecFilePathFormat -- operator entry point retains the Unicode witness name
  def unicode_columns(result, role)
    result.fetch(:columns).reject { |column| role == 'cache' && column.values_at('TABLE_NAME', 'COLUMN_NAME') == %w[request_rate_limit_counters counter_key] }
  end

  witness = nil
  # All assertions share an observed snapshot after its owned resources have been removed.
  before(:context) do # rubocop:disable RSpec/BeforeAfterAll -- all cases inspect one cleaned-up physical witness snapshot
    witness = described_class.new
    witness.run
  end

  it 'observes the original utf8 rejection against a full-Unicode destination' do
    expect(witness.baseline.fetch(:error_number)).to eq(1366)
    expect(witness.baseline.fetch(:settings).fetch('charset')).to eq('utf8mb3')
  end

  it 'round-trips the exact emoji-containing string in all four prepared databases' do
    expect(witness.results.keys.sort).to eq(%w[cable cache primary queue])
    expect(witness.results.values.map { |result| result.fetch(:round_trip).fetch(:exact) }).to all(be(true))
  end

  it 'uses full Unicode for all connections, database defaults, loaded tables and character columns' do
    expected_tables = {
      'primary' => [], 'cache' => ['solid_cache_entries'], 'cable' => ['solid_cable_messages'],
      'queue' => %w[solid_queue_batch_executions solid_queue_batches solid_queue_blocked_executions
                    solid_queue_claimed_executions solid_queue_failed_executions solid_queue_jobs solid_queue_pauses
                    solid_queue_processes solid_queue_ready_executions solid_queue_recurring_executions
                    solid_queue_recurring_tasks solid_queue_scheduled_executions solid_queue_semaphores]
    }
    witness.results.each do |role, result|
      actual_tables = result.fetch(:tables).map { |table| table.fetch('TABLE_NAME') }.select { |name| name.start_with?('solid_') }
      expect(actual_tables).to match_array(expected_tables.fetch(role))
      expect(result.fetch(:settings)).to eq('client' => 'utf8mb4', 'connection' => 'utf8mb4', 'results' => 'utf8mb4', 'collation' => 'utf8mb4_0900_ai_ci')
      expect(result.fetch(:database)).to eq('charset' => 'utf8mb4', 'collation' => 'utf8mb4_0900_ai_ci')
      expect(result.fetch(:tables).map { |table| table.fetch('TABLE_COLLATION') }).to all(eq('utf8mb4_0900_ai_ci'))
      expect(unicode_columns(result, role).map { |column| column.values_at('CHARACTER_SET_NAME', 'COLLATION_NAME') }).to all(eq(%w[utf8mb4 utf8mb4_0900_ai_ci]))
    end
  end

  it 'stores the fixed-format quota digest in its exact ASCII binary column' do
    column = witness.results.fetch('cache').fetch(:columns).find { |item| item.values_at('TABLE_NAME', 'COLUMN_NAME') == %w[request_rate_limit_counters counter_key] }
    expect(column.values_at('CHARACTER_SET_NAME', 'COLLATION_NAME')).to eq(%w[ascii ascii_bin])
  end

  it 'observes the temporary witness table and column collation in every database' do
    witness.results.each_value do |result|
      expect(result.fetch(:witness_column).find { |column| column.fetch('Field') == 'value' }.fetch('Collation')).to eq('utf8mb4_0900_ai_ci')
      expect(result.fetch(:witness_table)).to include('DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci')
    end
  end
end

exit RSpec::Core::Runner.run(['--options', '/dev/null', '--pattern', '/dev/null', *ARGV]) if $0 == __FILE__
