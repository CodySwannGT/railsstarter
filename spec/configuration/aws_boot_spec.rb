# frozen_string_literal: true

require 'open3'
require 'json'
require_relative '../../lib/aws_bootstrap'

# rubocop:disable-next RSpec/SpecFilePathFormat -- Separate process integration proof uses its own named boot spec.
RSpec.describe AwsBootstrap do
  def probe(scenario)
    output, status = Open3.capture2e(Gem.ruby, File.expand_path('fixtures/aws_boot_probe.rb', __dir__), scenario)
    line = output.lines.find { |entry| entry.start_with?('OWNED67_RESULT=') }
    raise "Probe did not produce observations: #{output}" unless line

    [JSON.parse(line.delete_prefix('OWNED67_RESULT=')), status]
  end

  %w[local test disabled].each do |scenario|
    it "boots and eager-loads #{scenario} without AWS requests or connections" do
      data, status = probe(scenario)
      expect(status).to be_success, data.inspect
      expect(data).to include('booted' => true, 'requests' => {}, 'driver_calls' => 0,
                              'network_calls' => 0, 'cleanup_complete' => true)
    end
  end

  it 'selects later pages and explicit identifiers before the actual deployed configuration is evaluated' do
    data, status = probe('success')
    expect(status).to be_success, data.inspect
    expect(data).to include('booted' => true, 'late_parameter' => true, 'selected_export' => true,
                            'remote_key' => true, 'selected_database_id' => true, 'regions_correct' => true,
                            'port' => 4406, 'adapter_port' => 4406, 'driver_calls' => 0, 'network_calls' => 0)
    expect(data['requests']).to include('get_parameters_by_path' => 2, 'list_exports' => 2, 'list_secrets' => 2)
  end

  it 'passes the database secret port to both actual adapters when SSM supplies no port' do
    data, status = probe('secret_port')
    expect(status).to be_success, data.inspect
    expect(data).to include('booted' => true, 'ssm_supplies_port' => false, 'selected_database_id' => true,
                            'port' => 4406, 'adapter_port' => 4406, 'replica_port' => 4406,
                            'replica_adapter_port' => 4406, 'driver_calls' => 0, 'network_calls' => 0,
                            'cleanup_complete' => true)
  end

  it 'retains supplied deployed environment overrides' do
    data, status = probe('overrides')
    expect(status).to be_success, data.inspect
    expect(data).to include('supplied_user' => true, 'supplied_key' => true, 'supplied_export' => true,
                            'supplied_password' => true, 'supplied_database' => true, 'supplied_host' => true,
                            'supplied_replica' => true, 'replica_port' => 4406,
                            'adapter_port' => 4406, 'driver_calls' => 0, 'network_calls' => 0)
  end

  it 'keeps caller selectors when later SSM pages contain redirection keys' do
    data, status = probe('selector_redirect')
    expect(status).to be_success, data.inspect
    expect(data).to include('selectors_preserved' => true, 'ssm_paths_correct' => true, 'regions_correct' => true,
                            'selected_export' => true, 'selected_database_id' => true, 'remote_key' => true)
  end

  it 'fills missing database fields even when the username is supplied' do
    data, status = probe('partial')
    expect(status).to be_success, data.inspect
    expect(data).to include('supplied_user' => true, 'remote_password' => true, 'adapter_port' => 4406)
  end

  it 'uses the same early bootstrap for staging' do
    data, status = probe('staging')
    expect(status).to be_success, data.inspect
    expect(data).to include('selected_export' => true, 'remote_key' => true, 'adapter_port' => 4406)
  end

  %w[assets assets_plain assets_leaked].each do |scenario|
    it "precompiles actual #{scenario} without constructing AWS clients or connecting to a database" do
      data, status = probe(scenario)
      expect(status).to be_success, data.inspect
      expect(data).to include('manifest_created' => true, 'requests' => {}, 'driver_calls' => 0,
                              'network_calls' => 0, 'cleanup_complete' => true)
    end
  end

  %w[denied prefix missing_id ssm_collision ssm_prefix].each do |scenario|
    it "rejects required deployed #{scenario} configuration visibly without leaking values" do
      data, status = probe(scenario)
      expect(status).not_to be_success
      expect(data).to include('error_class' => 'AwsBootstrap::Error', 'driver_calls' => 0,
                              'network_calls' => 0, 'cleanup_complete' => true)
      expect(data.fetch('error')).to include('AWS bootstrap')
      expect(data.to_json).not_to include('owned67_remote_password')
    end
  end

  %w[driver_guard network_guard].each do |scenario|
    it "proves the #{scenario} rejects an attempted connection before boot" do
      data, status = probe(scenario)
      expect(status).not_to be_success
      expect(data.fetch('error')).to include('connection forbidden')
      expect(data.values_at('driver_calls', 'network_calls').sum).to eq(1)
    end
  end
end
