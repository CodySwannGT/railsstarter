# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/synthetic_aws'
require 'rails_helper'
require 'json'

RSpec.describe 'Request database isolation', type: :request do
  # Read-role selection must use its actual pool instead of transactional fixture sharing.
  self.use_transactional_tests = false

  let(:configs) { ActiveRecord::Base.configurations.configs_for(env_name: 'test', include_hidden: true) }
  let(:selected) { configs.to_h { |config| [config.name, config.database] } }
  let(:snapshot) { collect_observations }

  def observe_database(config)
    constant = "TestDatabaseWitness#{config.name.camelize}"
    # rubocop:disable-next Rails/ApplicationRecord -- Independent probe pools must not inherit the application's role routing.
    stub_const(constant, Class.new(ActiveRecord::Base))
    witness = Object.const_get(constant)
    witness.abstract_class = true
    witness.establish_connection(config)
    witness.connection_pool.with_connection do |connection|
      connection.select_one('SELECT DATABASE() AS database_name, @@server_uuid AS server_uuid')
    end
  ensure
    witness&.connection_pool&.disconnect!
  end

  def write_evidence(data)
    path = ENV.fetch('ISSUE62_DATABASE_EVIDENCE_PATH', nil)
    return unless path

    File.open(path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) { |file| file.write(JSON.pretty_generate(data)) }
    File.chmod(0o600, path)
  end

  def sql_subscriber(trace)
    lambda do |*arguments|
      payload = arguments.last
      config = payload[:connection]&.pool&.db_config
      trace << { role: config.name, environment: config.env_name, database: config.database } if config
    end
  end

  def request_statuses
    %w[/ /up].map do |path|
      get path
      { path: path, status: response.status }
    end
  end

  def application_identities
    %i[writing reading].index_with do |role|
      ApplicationRecord.connected_to(role: role) do
        ApplicationRecord.connection_pool.with_connection do |connection|
          { role: connection.pool.db_config.name, database: connection.select_value('SELECT DATABASE()') }
        end
      end
    end
  end

  def collect_observations
    trace = []
    data = { selected: selected, sql_trace: trace }
    ActiveSupport::Notifications.subscribed(sql_subscriber(trace), 'sql.active_record') do
      data[:actual] = configs.to_h { |config| [config.name, observe_database(config)] }
      data[:requests] = request_statuses
      data[:application_roles] = application_identities
    end
    write_evidence(data)
    data
  end

  it 'physically selects every configured test database, including the hidden replica' do
    observed = snapshot.fetch(:actual)
    expect(configs.map(&:name)).to match_array(%w[primary primary_replica queue cache cable])
    expect(observed.transform_values { |identity| identity.fetch('database_name') }).to eq(selected)
    expect(observed.values.map { |identity| identity.fetch('server_uuid') }.uniq.length).to eq(1)
    expect(selected.values).to all(match(LISA_TEST_DATABASE_NAME))
  end

  it 'uses only test pools for real home and health requests and application reading and writing' do
    trace = snapshot.fetch(:sql_trace)
    expect(snapshot.fetch(:requests)).to eq([{ path: '/', status: 200 }, { path: '/up', status: 200 }])
    expect(snapshot.fetch(:application_roles)).to eq(
      writing: { role: 'primary', database: selected.fetch('primary') },
      reading: { role: 'primary_replica', database: selected.fetch('primary_replica') }
    )
    expect(trace.map { |entry| entry.fetch(:role) }).to include(*selected.keys)
    expect(trace.map { |entry| entry.fetch(:environment) }).to all(eq('test'))
    expect(trace.map { |entry| entry.fetch(:database) } - selected.values).to be_empty
  end
end
