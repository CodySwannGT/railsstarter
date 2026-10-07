# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'json'
require 'rbconfig'
require 'securerandom'
require 'tempfile'
require_relative '../fixtures/migrations/owned_mysql'

RSpec.describe 'Strong Migrations against owned MySQL' do # rubocop:disable RSpec/DescribeClass -- Exercises real migration and database behavior in fresh processes.
  attr_reader :owned_mysql

  before(:context) do # rubocop:disable RSpec/BeforeAfterAll -- Own one disposable server; every example uses a fresh child and DB, no transactional records shared.
    @owned_mysql = OwnedMigrationMysql.new.start unless ENV.key?('MIGRATION_PROBE_OWNERSHIP')
  end

  after(:context) do # rubocop:disable RSpec/BeforeAfterAll -- Release the exclusively owned external server even after failed examples.
    owned_mysql&.close
  end

  def ownership_path
    ENV.fetch('MIGRATION_PROBE_OWNERSHIP') { owned_mysql.receipt_path }
  end

  def ownership
    JSON.parse(File.read(ownership_path))
  end

  def probe(scenario, overrides = {})
    owner = ownership
    environment = {
      'RAILS_ENV' => 'test', 'RACK_ENV' => 'test',
      'DATABASE_NAME' => "#{owner.fetch('namespace_prefix')}_#{scenario}_#{SecureRandom.hex(4)}",
      'PRIMARY_DB_HOST' => '127.0.0.1', 'DATABASE_PORT' => owner.fetch('host_port').to_s,
      'DATABASE_USER' => 'root', 'DATABASE_PASSWORD' => nil,
      'MIGRATION_PROBE_OWNERSHIP' => ownership_path
    }.merge(overrides)
    fixture = File.expand_path('../fixtures/migrations/strong_migrations_probe.rb', __dir__)
    output, error, status = Open3.capture3(environment, RbConfig.ruby, fixture, scenario)
    record = output.lines.find { |line| line.start_with?('OWNED77_MIGRATION_RESULT=') }
    raise "Migration probe produced no result (#{status.exitstatus}): #{error}" unless record

    [JSON.parse(record.delete_prefix('OWNED77_MIGRATION_RESULT=')), status]
  end

  def expect_owned_execution(result, status)
    expect(status).to be_success
    expect(result).to include('native_preaccess' => true, 'daemon_owner_verified' => true,
                              'passed' => true, 'owned_database_absent' => true)
    expect(result.fetch('physical_identity')).to include('version' => '8.4.11', 'uuid' => ownership.fetch('server_uuid'))
    expect(result.fetch('settings')).to include('check_enabled' => true, 'safe_by_default' => true,
                                                'safety_assured' => false, 'direction' => 'up')
    expect(result.dig('before', 'rows')).to eq([[1, 2, 3, 4]])
    expect(result.dig('after', 'rows')).to eq(result.dig('before', 'rows'))
  end

  it 'rejects the actual four-column non-unique migration before index DDL with physical schema unchanged' do
    result, status = probe('unsafe')

    expect_owned_execution(result, status)
    expect(result.fetch('rejection')).to include('class' => 'StrongMigrations::UnsafeMigration')
    expect(result.dig('rejection', 'message')).to include('Best practice', 'Adding a non-unique index with more than three columns')
    expect(result.fetch('index_ddl')).to be_empty
    expect(result.fetch('schema_unchanged')).to be(true)
    expect(result.fetch('after')).to eq(result.fetch('before'))
  end

  it 'runs the documented d,b migration with checks active and observes the new physical index' do
    result, status = probe('safe')

    expect_owned_execution(result, status)
    expect(result).not_to have_key('rejection')
    expect(result.fetch('index_ddl').length).to eq(1)
    expect(result.fetch('schema_unchanged')).to be(false)
    expect(result.dig('after', 'indexes')).to eq([{ 'name' => 'owned77_safe_index', 'columns' => %w[d b], 'unique' => false }])
  end

  it 'allows a four-column unique index as the separate boundary defined by the actual check' do
    result, status = probe('unique')

    expect_owned_execution(result, status)
    expect(result).not_to have_key('rejection')
    expect(result.dig('after', 'indexes')).to eq([{ 'name' => 'owned77_unique_index', 'columns' => %w[a b c d], 'unique' => true }])
  end

  def expect_terminal_observer_receipt(line)
    expect(line).to start_with('OWNED77_AWS=')
    expect(JSON.parse(line.delete_prefix('OWNED77_AWS='))).to eq(
      'observer' => 'Seahorse::Client::NetHttp::Handler#call', 'metadata_lookup_disabled' => true, 'control_interceptions' => 1, 'observed_transport_attempts' => 0,
      'control_request' => { 'operation' => 'get_parameters_by_path', 'body' => { 'Path' => '/owned77/control/', 'Recursive' => true } },
      'stub_control' => { 'operation' => 'get_parameters_by_path', 'body' => { 'Path' => '/owned77/stub/', 'Recursive' => true },
                          'response' => [{ 'name' => '/owned77/stub/value', 'value' => 'owned77-synthetic-response' }], 'terminal_interceptions' => 0 }
    )
  end

  it 'intercepts real terminal HTTP but lets the actual SDK serialize and return its stub response' do
    fixture = File.expand_path('../fixtures/migrations/owned_mysql.rb', __dir__)
    output, error, status = Open3.capture3({ 'OWNED77_AWS_OBSERVER' => '1', 'AWS_EC2_METADATA_DISABLED' => nil },
                                           RbConfig.ruby, '-r', fixture, '-e', 'nil')

    expect(status).to be_success
    expect(output).to be_empty
    expect(error.lines.length).to eq(1)
    expect_terminal_observer_receipt(error)
  end

  it 'returns a nonzero CLI status and false success when cleanup raises (synthetic status control)' do
    fixture = File.expand_path('../fixtures/migrations/cleanup_failure_probe.rb', __dir__)
    output, error, status = Open3.capture3(RbConfig.ruby, fixture)
    record = output.lines.find { |line| line.start_with?('OWNED77_MIGRATION_RESULT=') }

    error.lines.each { |line| expect_terminal_observer_receipt(line) }
    expect(status.exitstatus).to eq(1)
    expect(JSON.parse(record.delete_prefix('OWNED77_MIGRATION_RESULT='))).to include('passed' => false, 'error_class' => 'ArgumentError', 'driver_connections' => 0)
  end

  it 'rejects a non-test environment before database access' do
    result, status = probe('unsafe', 'RAILS_ENV' => 'production')

    expect(status).not_to be_success
    expect(result).to include('refused' => true, 'driver_connections' => 0, 'index_ddl' => [])
    expect(result).not_to have_key('database')
  end

  it 'rejects a test-named foreign namespace before database access' do
    result, status = probe('unsafe', 'DATABASE_NAME' => 'foreign77')

    expect(status).not_to be_success
    expect(result).to include('refused' => true, 'native_preaccess' => true, 'driver_connections' => 0, 'index_ddl' => [])
    expect(result).not_to have_key('database')
  end

  it 'refuses a SAFETY_ASSURED bypass before database access' do
    result, status = probe('unsafe', 'SAFETY_ASSURED' => '1')

    expect(status).not_to be_success
    expect(result).to include('refused' => true, 'driver_connections' => 0, 'index_ddl' => [])
  end

  it 'refuses a wrong loopback port before database access' do
    result, status = probe('unsafe', 'DATABASE_PORT' => '1')

    expect(status).not_to be_success
    expect(result).to include('refused' => true, 'driver_connections' => 0, 'index_ddl' => [])
  end

  it 'refuses a mismatched physical server UUID without creating a database' do
    Tempfile.create(['owned77-server-identity-', '.json']) do |file|
      file.write(JSON.generate(ownership.merge('server_uuid' => '00000000-0000-0000-0000-000000000000')))
      file.flush
      result, status = probe('unsafe', 'MIGRATION_PROBE_OWNERSHIP' => file.path)

      expect(status).not_to be_success
      expect(result).to include('refused' => true, 'daemon_owner_verified' => true, 'driver_connections' => 1, 'index_ddl' => [])
      expect(result).not_to have_key('before')
      expect(result).not_to have_key('owned_database_absent')
    end
  end
end
