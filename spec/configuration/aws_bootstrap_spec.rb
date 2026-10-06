# frozen_string_literal: true

require 'aws-sdk-ssm'
require 'aws-sdk-cloudformation'
require 'aws-sdk-secretsmanager'
require_relative '../../lib/aws_bootstrap'

RSpec.describe AwsBootstrap do
  let(:env) do
    {
      'AWS_BOOTSTRAP_ENABLED' => 'true', 'AWS_REGION' => 'us-west-2', 'AWS_SSM_PATH' => '/owned67/',
      'AWS_DATABASE_SECRET_ID' => 'owned67/database', 'AWS_SECRET_KEY_BASE_SECRET_ID' => 'owned67/key'
    }
  end
  let(:ssm) { Aws::SSM::Client.new(stub_responses: true, region: 'us-west-2') }
  let(:exports) { Aws::CloudFormation::Client.new(stub_responses: true, region: 'us-west-2') }
  let(:secrets) { Aws::SecretsManager::Client.new(stub_responses: true, region: 'us-west-2') }

  before do
    ssm.stub_responses(:get_parameters_by_path, [
                         { parameters: [{ name: '/owned67/database_port', value: '4406' }], next_token: 'later' },
                         { parameters: [{ name: '/owned67/redis_cache_port', value: '6381' }] }
                       ])
    exports.stub_responses(:list_exports, [
                             { exports: [], next_token: 'later' },
                             { exports: [{ name: 'assetDomain', value: 'https://owned67.invalid' },
                                         { name: 'redisCachePort', value: '6380' }] }
                           ])
    secrets.stub_responses(:list_secrets, [
                             { secret_list: [{ name: 'owned67/database-wrong' }], next_token: 'later' },
                             { secret_list: [{ name: 'owned67/database', arn: 'arn:owned67:database' },
                                             { name: 'owned67/key', arn: 'arn:owned67:key' }] }
                           ])
    secrets.stub_responses(:get_secret_value, lambda do |context|
      if context.params[:secret_id] == 'arn:owned67:key'
        { secret_string: 'owned67_remote_key' }
      else
        { secret_string: JSON.generate(username: 'owned67_user', password: 'owned67_password',
                                       dbname: 'owned67_db', host: 'owned67.cluster-host.invalid', port: 3306) }
      end
    end)
    allow(Aws::SSM::Client).to receive(:new).with(region: 'us-west-2').and_return(ssm)
    allow(Aws::CloudFormation::Client).to receive(:new).with(region: 'us-west-2').and_return(exports)
    allow(Aws::SecretsManager::Client).to receive(:new).with(region: 'us-west-2').and_return(secrets)
  end

  def load_configuration
    described_class.load!(environment: 'production', env: env, asset_compilation: false)
  end

  it 'applies incoming ENV then SSM then exports then database fields, with complete pagination' do
    env['DATABASE_USER'] = 'supplied_user'
    load_configuration
    expect(env).to include('DATABASE_USER' => 'supplied_user', 'DATABASE_PORT' => '4406',
                           'REDIS_CACHE_PORT' => '6381', 'DATABASE_PASSWORD' => 'owned67_password',
                           'DATABASE_REPLICA_HOST' => 'owned67.cluster-ro-host.invalid')
    expect(ssm.api_requests.map { |request| request[:params][:next_token] }).to eq([nil, 'later'])
    expect(exports.api_requests.size).to eq(2)
    expect(secrets.api_requests.count { |request| request[:operation_name] == :list_secrets }).to eq(2)
  end

  it 'normalizes the configured SSM path and requests decryption recursively' do
    load_configuration
    expect(ssm.api_requests.first[:params]).to include(path: '/owned67/', recursive: true, with_decryption: true)
  end

  it 'honors exact identifiers including ARNs over a conflicting prefix' do
    env['AWS_DATABASE_SECRET_ID'] = 'arn:owned67:database'
    env['AWS_DATABASE_SECRET_PREFIX'] = 'owned67/database'
    load_configuration
    expect(secrets.api_requests.select { |request| request[:operation_name] == :get_secret_value }
                  .map { |request| request[:params][:secret_id] }).to eq(['arn:owned67:database', 'arn:owned67:key'])
  end

  it 'rejects a conflicting prefix that becomes ambiguous on a later page' do
    env.delete('AWS_DATABASE_SECRET_ID')
    env['AWS_DATABASE_SECRET_PREFIX'] = 'owned67/database'
    expect { load_configuration }.to raise_error(described_class::Error, /missing or ambiguous/)
  end

  it 'uses a unique explicitly configured prefix' do
    env.delete('AWS_DATABASE_SECRET_ID')
    env['AWS_DATABASE_SECRET_PREFIX'] = 'owned67/database-wrong'
    load_configuration
    expect(env['DATABASE_NAME']).to eq('owned67_db')
  end

  it 'captures selectors before SSM values can redirect subsequent lookups' do
    ssm.stub_responses(:get_parameters_by_path, parameters: [
                         { name: '/owned67/aws_database_secret_id', value: 'untrusted-selector' },
                         { name: '/owned67/aws_region', value: 'untrusted-region' }
                       ])
    load_configuration
    expect(env['AWS_DATABASE_SECRET_ID']).to eq('owned67/database')
    expect(env['AWS_REGION']).to eq('us-west-2')
    expect(secrets.api_requests.any? { |request| request[:params][:secret_id] == 'arn:owned67:database' }).to be(true)
  end

  it 'rejects transformed SSM key collisions across pages atomically' do
    original = env.dup
    ssm.stub_responses(:get_parameters_by_path, [
                         { parameters: [{ name: '/owned67/foo/bar', value: 'one' }], next_token: 'later' },
                         { parameters: [{ name: '/owned67/foo_bar', value: 'two' }] }
                       ])
    expect { load_configuration }.to raise_error(described_class::Error, /conflicting SSM/)
    expect(env).to eq(original)
  end

  it 'rejects parameters from a neighboring prefix' do
    ssm.stub_responses(:get_parameters_by_path, parameters: [{ name: '/owned670/key', value: 'one' }])
    expect { load_configuration }.to raise_error(described_class::Error, /outside configured path/)
  end

  it 'rejects repeated tokens instead of looping indefinitely' do
    ssm.stub_responses(:get_parameters_by_path, parameters: [], next_token: 'repeated')
    expect { load_configuration }.to raise_error(described_class::Error, /repeated pagination token/)
  end

  it 'rejects duplicate export names across pages' do
    exports.stub_responses(:list_exports, [
                             { exports: [{ name: 'assetDomain', value: 'one' }], next_token: 'later' },
                             { exports: [{ name: 'assetDomain', value: 'two' }] }
                           ])
    expect { load_configuration }.to raise_error(described_class::Error, /conflicting CloudFormation/)
  end

  it 'requires a configured exact export without accepting a prefix neighbor' do
    env['AWS_EXPORT_CLOUDFRONT_ENDPOINT'] = 'assetDomainMissing'
    expect { load_configuration }.to raise_error(described_class::Error, /export is missing/)
  end

  it 'does not require secret lookup when every required value is already supplied' do
    env.merge!('DATABASE_USER' => 'user', 'DATABASE_PASSWORD' => 'password', 'DATABASE_NAME' => 'owned67',
               'PRIMARY_DB_HOST' => 'owned67.invalid', 'DATABASE_PORT' => '4406', 'SECRET_KEY_BASE' => 'supplied')
    load_configuration
    expect(Aws::SecretsManager::Client).not_to have_received(:new).with(region: 'us-west-2')
    expect(env['SECRET_KEY_BASE']).to eq('supplied')
  end

  it 'sanitizes required provider errors without leaking exception messages or causes' do
    secrets.stub_responses(:get_secret_value, Aws::SecretsManager::Errors::AccessDeniedException.new(nil, 'secret-value-leak'))
    expect { load_configuration }.to raise_error(described_class::Error) { |error|
      expect(error.message).to include('get_secret_value failed', 'AccessDeniedException')
      expect(error.message).not_to include('secret-value-leak')
      expect(error.cause).to be_nil
    }
  end

  it 'rejects incomplete deployed secret data visibly' do
    secrets.stub_responses(:get_secret_value, secret_string: '{}')
    expect { load_configuration }.to raise_error(described_class::Error, /required deployed configuration/)
  end

  it 'rejects invalid secret JSON without its original data' do
    secrets.stub_responses(:get_secret_value, secret_string: 'secret-value-leak')
    expect { load_configuration }.to raise_error(described_class::Error, /invalid JSON/)
  end

  %w[development test].each do |environment|
    it "does not construct clients in #{environment} without opt-in" do
      described_class.load!(environment: environment, env: {}, asset_compilation: false)
      expect(Aws::SSM::Client).not_to have_received(:new).with(region: 'us-west-2')
    end
  end

  it 'treats dummy compilation as a hard boundary even with opt-in' do
    env['SECRET_KEY_BASE_DUMMY'] = '1'
    load_configuration
    expect(Aws::SSM::Client).not_to have_received(:new).with(region: 'us-west-2')
  end

  it 'does not default deployed asset compilation to AWS without opt-in' do
    env.delete('AWS_BOOTSTRAP_ENABLED')
    described_class.load!(environment: 'production', env: env, asset_compilation: true)
    expect(Aws::SSM::Client).not_to have_received(:new).with(region: 'us-west-2')
  end

  it 'does not permit an invalid enablement setting' do
    env['AWS_BOOTSTRAP_ENABLED'] = 'yes'
    expect { load_configuration }.to raise_error(described_class::Error, /must be true or false/)
  end

  %w[production staging].each do |environment|
    it "defaults #{environment} to bootstrap when no flag is supplied" do
      env.delete('AWS_BOOTSTRAP_ENABLED')
      described_class.load!(environment: environment, env: env, asset_compilation: false)
      expect(env['SECRET_KEY_BASE']).to eq('owned67_remote_key')
    end

    it "permits explicit disabling in #{environment}" do
      env['AWS_BOOTSTRAP_ENABLED'] = 'false'
      described_class.load!(environment: environment, env: env, asset_compilation: false)
      expect(ssm.api_requests).to be_empty
    end
  end

  [nil, '', 'TRUE', 'False', '1', true, false].each do |flag|
    it "rejects noncanonical bootstrap flag #{flag.inspect} before constructing a client" do
      env['AWS_BOOTSTRAP_ENABLED'] = flag
      expect { load_configuration }.to raise_error(described_class::Error, /must be true or false/)
      expect(ssm.api_requests).to be_empty
    end

    it "skips asset compilation with noncanonical opt-in #{flag.inspect} before flag validation" do
      env['AWS_BOOTSTRAP_ENABLED'] = flag
      described_class.load!(environment: 'production', env: env, asset_compilation: true)
      expect(ssm.api_requests).to be_empty
    end
  end

  ['', '0', 'false'].each do |dummy|
    it "treats the dummy value #{dummy.inspect} as truthy before evaluating deployment or flags" do
      environment = Object.new
      allow(environment).to receive(:to_s).and_raise('deployment must not be evaluated')
      env.merge!('SECRET_KEY_BASE_DUMMY' => dummy, 'AWS_BOOTSTRAP_ENABLED' => 'invalid')
      described_class.load!(environment: environment, env: env, asset_compilation: false)
      expect(ssm.api_requests).to be_empty
    end
  end

  [nil, false].each do |dummy|
    it "continues actual bootstrap with falsey dummy value #{dummy.inspect}" do
      env['SECRET_KEY_BASE_DUMMY'] = dummy
      load_configuration
      expect(env['SECRET_KEY_BASE']).to eq('owned67_remote_key')
    end
  end

  it 'uses the actual ENV keyword default and preserves the loaded return value' do
    stub_const('ENV', env)
    result = described_class.load!(environment: 'production', asset_compilation: false)
    expect(result['SECRET_KEY_BASE']).to eq('owned67_remote_key')
    expect(env['DATABASE_NAME']).to eq('owned67_db')
  end

  it 'reads the current ARGV default for the exact precompile task' do
    stub_const('ARGV', ['assets:precompile'])
    env.delete('AWS_BOOTSTRAP_ENABLED')
    expect(described_class.load!(environment: 'production', env: env)).to be_nil
    expect(ssm.api_requests).to be_empty
  end

  it 'does not treat a different asset task as the precompile boundary' do
    stub_const('ARGV', ['assets:clean'])
    env.delete('AWS_BOOTSTRAP_ENABLED')
    described_class.load!(environment: 'production', env: env)
    expect(env['SECRET_KEY_BASE']).to eq('owned67_remote_key')
  end

  it 'allows explicit opt-in during the exact precompile task' do
    stub_const('ARGV', ['assets:precompile'])
    described_class.load!(environment: 'production', env: env)
    expect(env['SECRET_KEY_BASE']).to eq('owned67_remote_key')
  end

  it 'evaluates the deployment name once after the early guards' do
    environment = 'production'.dup
    allow(environment).to receive(:to_s).and_call_original
    described_class.load!(environment: environment, env: env, asset_compilation: false)
    expect(environment).to have_received(:to_s).once
    expect(env['SECRET_KEY_BASE']).to eq('owned67_remote_key')
  end

  it 'retains explicit nil ENV keys while returning resolved remote values' do
    env['DATABASE_USER'] = nil
    result = load_configuration
    expect(env['DATABASE_USER']).to be_nil
    expect(result['DATABASE_USER']).to eq('owned67_user')
  end

  it 'fails closed for an explicitly empty required deployed value without partial ENV writes' do
    env['DATABASE_USER'] = ''
    original = env.dup
    expect { load_configuration }.to raise_error(described_class::Error, /required deployed configuration/)
    expect(env).to eq(original)
  end

  it 'rejects a root SSM path before constructing a client' do
    env['AWS_SSM_PATH'] = '///'
    expect { load_configuration }.to raise_error(described_class::Error, /SSM path must not be root/)
    expect(ssm.api_requests).to be_empty
  end

  it 'rejects an invalid transformed SSM key without partial ENV writes' do
    original = env.dup
    ssm.stub_responses(:get_parameters_by_path, parameters: [{ name: '/owned67/1invalid', value: 'private-value' }])
    expect { load_configuration }.to raise_error(described_class::Error, /invalid or conflicting SSM/)
    expect(env).to eq(original)
  end

  %w[SSM CloudFormation SecretsManager].each do |service|
    it "sanitizes #{service} client construction failures and preserves ENV" do
      original = env.dup
      allow(Aws.const_get(service)::Client).to receive(:new).and_raise(ArgumentError, 'private-provider-value')
      expect { load_configuration }.to raise_error(described_class::Error) { |error|
        expect(error.message).to eq('AWS bootstrap: client construction failed (ArgumentError)')
        expect(error.cause).to be_nil
      }
      expect(env).to eq(original)
    end
  end

  { ssm: :get_parameters_by_path, exports: :list_exports, secrets: :list_secrets }.each do |service, operation|
    it "sanitizes actual SDK #{operation} failures without partial ENV writes" do
      original = env.dup
      public_send(service).stub_responses(operation, Seahorse::Client::NetworkingError.new(IOError.new('private-provider-value')))
      expect { load_configuration }.to raise_error(described_class::Error) { |error|
        expect(error.message).to eq("AWS bootstrap: #{operation} failed (Seahorse::Client::NetworkingError)")
        expect(error.cause).to be_nil
      }
      expect(env).to eq(original)
    end
  end

  it 'rejects repeated CloudFormation tokens without exposing the token' do
    exports.stub_responses(:list_exports, exports: [], next_token: 'private-token')
    expect { load_configuration }.to raise_error(described_class::Error, 'AWS bootstrap: list_exports repeated pagination token')
  end

  it 'rejects repeated Secrets Manager tokens without exposing the token' do
    secrets.stub_responses(:list_secrets, secret_list: [], next_token: 'private-token')
    expect { load_configuration }.to raise_error(described_class::Error, 'AWS bootstrap: list_secrets repeated pagination token')
  end

  it 'rejects a nonobject database secret without exposing its contents' do
    secrets.stub_responses(:get_secret_value, secret_string: '["private-value"]')
    expect { load_configuration }.to raise_error(described_class::Error, 'AWS bootstrap: database secret must be an object')
  end

  it 'rejects a missing secret string instead of swallowing bootstrap failure' do
    secrets.stub_responses(:get_secret_value, secret_binary: 'private-value')
    expect { load_configuration }.to raise_error(described_class::Error, 'AWS bootstrap: secret string is missing')
  end

  it 'retains the public instance load! operation and its return value' do
    result = described_class.new(env, deployed: true).load!
    expect(result['SECRET_KEY_BASE']).to eq('owned67_remote_key')
    expect(env['DATABASE_NAME']).to eq('owned67_db')
  end
end
