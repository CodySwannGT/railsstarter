# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'json'
require 'rbconfig'

RSpec.describe 'Rails helper isolation' do # rubocop:disable RSpec/DescribeClass -- The helper file is tested before Rails can load its module.
  def probe(scenario, environment, role = 'primary')
    path = File.expand_path('../fixtures/safety/rails_helper_probe.rb', __dir__)
    output, error, status = Open3.capture3(RbConfig.ruby, path, scenario, environment, role)
    record = output.lines.find { |line| line.start_with?('OWNED62_RESULT=') }
    raise "Helper probe produced no result: #{error}" unless record

    [JSON.parse(record.delete_prefix('OWNED62_RESULT=')), status, error]
  end

  %w[development staging production].each do |environment|
    it "rejects #{environment} before host boot, database connections, schema maintenance or cleanup" do
      result, status, error = probe('current', environment)

      expect(status).not_to be_success
      expect(error).to include('Rails test isolation:')
      expect(result).to include('booted' => false, 'cleanup_complete' => true, 'exit_status' => 1)
      expect(result.fetch('events')).to eq('driver' => 0, 'schema_maintenance' => 0, 'cleanup' => 0)
    end
  end

  it 'rejects a conflicting Rack environment before host boot' do
    result, status, error = probe('rack_mismatch', 'test')

    expect(status).not_to be_success
    expect(error).to include('Rails test isolation:')
    expect(result.fetch('booted')).to be(false)
    expect(result.fetch('events').values).to all(eq(0))
  end

  %w[primary primary_replica].each do |role|
    it "rejects a non-test #{role} URL override before host boot" do
      result, status, error = probe('unsafe_url', 'test', role)

      expect(status).not_to be_success
      expect(error).to include('Rails test isolation:')
      expect(result.fetch('booted')).to be(false)
      expect(result.fetch('events').values).to all(eq(0))
    end
  end

  %w[primary primary_replica queue cache cable].each do |role|
    it "rejects a postboot non-test #{role} identity before database connections, schema maintenance or cleanup" do
      result, status, error = probe('postboot_invalid', 'test', role)

      expect(status).not_to be_success
      expect(error).to include('Rails test isolation:')
      expect(result).to include('booted' => true, 'cleanup_complete' => true, 'exit_status' => 1)
      expect(result.fetch('events')).to eq('driver' => 0, 'schema_maintenance' => 0, 'cleanup' => 0)
    end
  end

  it 'reaches all tripwires with the historical development helper as a regression control' do
    result, status, = probe('legacy', 'development')

    expect(status).not_to be_success
    expect(result).to include('booted' => true, 'tripwire_reached' => true, 'cleanup_complete' => true)
    expect(result.fetch('events')).to eq('driver' => 1, 'schema_maintenance' => 1, 'cleanup' => 1)
  end

  it 'reaches all tripwires with valid synthetic test configuration as a control' do
    result, status, = probe('current', 'test')

    expect(status).not_to be_success
    expect(result).to include('booted' => true, 'tripwire_reached' => true, 'cleanup_complete' => true)
    expect(result.fetch('events')).to eq('driver' => 1, 'schema_maintenance' => 1, 'cleanup' => 1)
  end
end
