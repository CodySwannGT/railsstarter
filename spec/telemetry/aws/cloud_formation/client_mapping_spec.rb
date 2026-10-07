# frozen_string_literal: true

require 'aws-sdk-cloudformation'
require 'aws-sdk-ssm'
require 'aws-sdk-secretsmanager'
require 'active_support/core_ext/enumerable'
require_relative '../../../../lib/aws_bootstrap'

RSpec.describe Aws::CloudFormation::Client do
  let(:client) { described_class.new(region: 'eu-west-1', stub_responses: true) }
  let(:ssm) { Aws::SSM::Client.new(region: 'eu-west-1', stub_responses: true) }
  let(:env) do
    {
      'AWS_BOOTSTRAP_ENABLED' => 'true', 'AWS_REGION' => 'eu-west-1',
      'DATABASE_USER' => 'synthetic', 'DATABASE_PASSWORD' => 'synthetic',
      'DATABASE_NAME' => 'synthetic_test', 'PRIMARY_DB_HOST' => 'database.example.invalid',
      'DATABASE_PORT' => '4406', 'SECRET_KEY_BASE' => 'synthetic'
    }
  end
  let(:unsupported_settings) do
    %w[REDIS_CACHE_ENDPOINT_URL REDIS_CACHE_PORT DEFAULT_QUEUE_URL EMAIL_QUEUE_URL CENSUS_QUEUE_URL]
  end

  before do
    exports = [
      { name: 'assetDomain', value: 'assets.example.invalid' },
      { name: 'assetDomainSynthetic', value: 'neighbor.example.invalid' },
      { name: 'redisCacheEndpointUrl', value: 'synthetic-cache' },
      { name: 'redisCachePort', value: '6379' },
      { name: 'QueueUrl', value: 'synthetic-queue' },
      { name: 'EmailQueueUrl', value: 'synthetic-email' },
      { name: 'CensusQueueUrl', value: 'synthetic-census' }
    ]
    client.stub_responses(:list_exports, exports: exports)
    ssm.stub_responses(:get_parameters_by_path, parameters: [])
    allow(described_class).to receive(:new).with(region: 'eu-west-1').and_return(client)
    allow(Aws::SSM::Client).to receive(:new).with(region: 'eu-west-1').and_return(ssm)
  end

  def load_configuration
    AwsBootstrap.load!(environment: 'test', env: env, asset_compilation: false)
  end

  it 'retains the exact consumed asset-domain mapping through the opted-in final bootstrap' do
    load_configuration
    expect(env.fetch('CLOUDFRONT_ENDPOINT')).to eq('assets.example.invalid')
    expect(client.api_requests.pluck(:operation_name)).to eq([:list_exports])
    expect(ssm.api_requests.pluck(:operation_name)).to eq([:get_parameters_by_path])
    expect(ssm.api_requests.first[:params]).to eq(path: '/app/', recursive: true, with_decryption: true)
  end

  it 'uses an explicitly selected exact asset export' do
    env['AWS_EXPORT_CLOUDFRONT_ENDPOINT'] = 'assetDomainSynthetic'
    load_configuration
    expect(env.fetch('CLOUDFRONT_ENDPOINT')).to eq('neighbor.example.invalid')
  end

  it 'rejects a missing exact asset export without choosing its prefix neighbor' do
    env['AWS_EXPORT_CLOUDFRONT_ENDPOINT'] = 'assetDomainMissing'
    expect { load_configuration }.to raise_error(AwsBootstrap::Error, /export is missing/)
    expect(env).not_to have_key('CLOUDFRONT_ENDPOINT')
  end

  it 'preserves an explicitly configured asset domain' do
    env['CLOUDFRONT_ENDPOINT'] = 'explicit.example.invalid'
    load_configuration
    expect(env.fetch('CLOUDFRONT_ENDPOINT')).to eq('explicit.example.invalid')
  end

  it 'does not manufacture settings from unused Redis and queue exports' do
    load_configuration
    expect(env.keys & unsupported_settings).to be_empty
    expect(client.api_requests.pluck(:operation_name)).to eq([:list_exports])
  end

  it 'does not overwrite explicitly configured unsupported settings' do
    unsupported_settings.each { |key| env[key] = 'explicit-setting' }
    load_configuration
    expect(env.slice(*unsupported_settings).values.uniq).to eq(['explicit-setting'])
  end

  it 'constructs no SDK client in local test boot without opt-in' do
    env.delete('AWS_BOOTSTRAP_ENABLED')
    load_configuration
    expect(described_class).not_to have_received(:new)
    expect(Aws::SSM::Client).not_to have_received(:new)
    expect(client.api_requests).to be_empty
    expect(ssm.api_requests).to be_empty
  end

  it 'constructs no SDK client during dummy asset compilation even with opt-in' do
    env['SECRET_KEY_BASE_DUMMY'] = '1'
    load_configuration
    expect(described_class).not_to have_received(:new)
    expect(Aws::SSM::Client).not_to have_received(:new)
    expect(client.api_requests).to be_empty
    expect(ssm.api_requests).to be_empty
  end
end
