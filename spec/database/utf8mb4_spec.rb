# frozen_string_literal: true

require 'active_record'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# Executes the mandatory physical witness without importing its Active Record state.
module Database
  module Utf8mb4
    def self.run
      root = File.expand_path('../..', __dir__)
      Dir.mktmpdir('unicode-rspec-results-') do |directory|
        report_path = File.join(directory, 'results.json')
        output, error, status = Open3.capture3(RbConfig.ruby, File.join(root, 'test/runtime/utf8mb4_spec.rb'),
                                               '--format', 'documentation', '--format', 'json', '--out', report_path)
        raise "Unicode child failed (#{status.exitstatus}):\n#{output}\n#{error}" unless status.success?

        [JSON.parse(File.read(report_path)), output.lines.filter_map { |line| JSON.parse(line) if line.start_with?('{') }]
      end
    end

    def self.physical_receipt(events)
      grouped = events.group_by { |event| event.fetch('event') }
      [grouped.fetch('original_utf8_rejection').fetch(0).fetch('data').fetch('error_number'),
       grouped.fetch('database_witness').map { |event| event.fetch('data').fetch('role') }.sort,
       grouped.fetch('cleanup').fetch(0).fetch('data')]
    end
  end
end

RSpec.describe Database::Utf8mb4 do
  let(:original_pool) { ActiveRecord::Base.connection_handler.retrieve_connection_pool('ActiveRecord::Base') }
  let(:parent_pool) do
    # Creating this pool only records configuration. No sentinel connection is opened.
    unless original_pool
      ActiveRecord::Base.establish_connection(adapter: 'mysql2', host: 'never-connect.invalid',
                                              database: 'sentinel_no_connection', username: 'sentinel', port: 1)
    end
    ActiveRecord::Base.connection_pool
  end

  after do
    ActiveRecord::Base.remove_connection unless original_pool
  end

  it 'executes every physical case in a child without changing or connecting the parent pool' do
    pool = parent_pool
    configuration = pool.db_config.configuration_hash
    connected = pool.connected?
    report, events = described_class.run
    expect([report.fetch('summary').values_at('example_count', 'failure_count', 'pending_count'),
            report.fetch('examples').map { |example| example.fetch('status') }]).to eq([[5, 0, 0], Array.new(5, 'passed')])
    expect(described_class.physical_receipt(events)).to eq([1366, %w[cable cache primary queue],
                                                            { 'container_absent' => true, 'volume_absent' => true }])
    expect([ActiveRecord::Base.connection_pool, pool.db_config.configuration_hash, pool.connected?]).to eq([pool, configuration, connected])
  end
end
