# frozen_string_literal: true

require 'open3'
require 'json'
require 'rbconfig'

RSpec.describe 'Deployed request security' do
  let(:rejection_modes) { %w[missing blank invalid dummy mixed] }

  def probe(mode, profile = 'production')
    output, status = Open3.capture2e(RbConfig.ruby, File.expand_path('../fixtures/requests/request_security_probe.rb', __dir__), mode, profile)
    line = output.lines.find { |entry| entry.start_with?('REQUEST_SECURITY_RESULT=') }
    raise output unless line

    observation = JSON.parse(line.delete_prefix('REQUEST_SECURITY_RESULT='))
    expect(observation['scratch_removed']).to be(true)
    expect(observation.dig('aws', 'requests')).to eq([])
    [observation, status.exitstatus, output]
  end

  %w[production staging].each do |profile|
    it "rejects missing, blank, invalid and ordinary dummy hosts in #{profile}" do
      rejection_modes.each do |mode|
        observation, status, output = probe(mode, profile)
        expect(status).to eq(1), observation.inspect
        expect(observation['error'] || output).to include('ALLOWED_HOSTS')
        expect(observation['guards']).to eq('network' => 0, 'database' => 0)
      end
    end

    it "reaches real host, health and SSL middleware in #{profile}" do
      observation, status = probe('valid', profile)
      expect(status).to eq(0), observation.inspect
      expect_deployed_boundaries(observation)
    end

    it "compiles actual assets with dummy build context and no hosts in #{profile}" do
      observation, status = probe('assets', profile)
      expect(status).to eq(0), observation.inspect
      expect(observation['manifest_created']).to be(true)
      expect(observation['asset_count']).to be_positive
      expect(observation['guards']).to eq('network' => 0, 'database' => 0)
    end
  end

  def expect_deployed_boundaries(observation)
    expect(observation['responses'].transform_values { |entry| entry['status'] })
      .to eq('allowed' => 200, 'unexpected' => 403, 'forwarded' => 403, 'health' => 200,
             'health_slash' => 403, 'neighbor' => 403, 'encoded' => 403, 'upper' => 403)
    expect_ssl_boundaries(observation)
    expect(observation['middleware']).to include('ActionDispatch::HostAuthorization', 'ActionDispatch::SSL')
    expect(observation.dig('responses', 'allowed', 'csp')).to include("default-src 'self'", "object-src 'none'")
    expect(observation['guards']).to eq('network' => 0, 'database' => 0)
  end

  def expect_ssl_boundaries(observation)
    expect(observation['ssl']).to eq('/up?query=1' => 200, '/' => 301, '/up/' => 301, '/up-other' => 301)
    expect(observation['ssl_control_without_exclusion']).to eq(301)
    expect(observation.values_at('assume_ssl', 'force_ssl')).to eq([true, true])
  end

  it 'proves the network and database tripwires reach before guarded boot' do
    %w[network_guard driver_guard].each do |mode|
      observation, status = probe(mode)
      expect(status).to eq(1)
      expect(observation['error']).to include('guard reached')
      expect(observation['guards'].values.sum).to eq(1)
    end
  end

  it 'detects removal of real host middleware in a disposable control' do
    observation, status = probe('host_control')
    expect(status).to eq(0)
    expect(observation.dig('responses', 'unexpected', 'status')).to eq(200)
    expect(observation['middleware']).not_to include('ActionDispatch::HostAuthorization')
  end
end
