# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'
require 'rbconfig'
require 'rails'
require 'action_dispatch'
require 'action_view'
require_relative '../fixtures/runtime/smoke'

RSpec.describe DependencySmoke do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:harness) { File.join(root, 'spec/fixtures/runtime/smoke.rb') }
  let(:environment) do
    ENV.to_h.select { |key, _value| key.match?(/\A(?:AWS_|OTEL_|DATABASE|PRIMARY_DB_HOST|CLOUDFRONT_ENDPOINT)|_DATABASE_URL\z/) }
       .transform_values { nil }
       .merge('RAILS_ENV' => 'test', 'RACK_ENV' => 'test', 'RUNTIME_SMOKE_DB' => '0', 'RUNTIME_SMOKE_IMAGE' => '0')
  end
  let(:image_environment) do
    { 'RUNTIME_SMOKE_IMAGE' => '1', 'RAILS_ENV' => 'production', 'RACK_ENV' => 'production',
      'RUNTIME_SMOKE_DB' => '1', 'DATABASE_NAME' => 'railsstarter_63_smoke_spec',
      'PRIMARY_DB_HOST' => '127.0.0.1', 'DATABASE_PORT' => '13363', 'DATABASE_USER' => 'runtime_smoke',
      'DATABASE_PASSWORD' => 'authored-only', 'BUNDLE_DEPLOYMENT' => '1', 'BUNDLE_PATH' => '/usr/local/bundle',
      'BUNDLE_WITHOUT' => 'development:test', 'RAILS_GROUPS' => nil, 'SECRET_KEY_BASE_DUMMY' => nil }
  end

  def run_smoke(overrides = {})
    Open3.capture3(environment.merge(overrides), RbConfig.ruby, harness, chdir: root)
  end

  it 'sends the authored image host through real host authorization and retains foreign-host refusal' do
    body = 'Welcome to Your Project background-color: green'
    app = ActionDispatch::HostAuthorization.new(->(_env) { [200, { 'content-type' => 'text/html' }, [body]] }, ['example.org'])
    allow(Rails).to receive(:application).and_return(app)
    allow(described_class).to receive(:image_mode?).and_return(true)

    expect(described_class.requests.map { |request| request.fetch(:status) }).to eq([200, 200])
    expect(Rack::MockRequest.new(app).get('/', 'HTTP_HOST' => 'foreign.example.test').status).to eq(403)
  end

  it 'boots, eager loads and renders home and health without AWS requests in local test mode' do
    stdout, stderr, status = run_smoke
    expect(status.success?).to be(true), "#{stdout}\n#{stderr}"
    result = JSON.parse(stdout).fetch('runtime_smoke_result')
    expect(result).to include('boot' => 'test', 'eager_load' => true, 'databases' => [], 'aws_requests' => {})
    expect(result.fetch('requests').map { |request| [request.fetch('path'), request.fetch('status')] })
      .to eq([['/', 200], ['/up', 200]])
    expect(result.fetch('versions').keys).to include('rails', 'activestorage', 'json', 'loofah', 'mail', 'rails-html-sanitizer')
    expect(result.fetch('aws')).to eq('bootstrap_enabled' => 'false', 'stub_responses' => true,
                                      'requests' => [], 'fixture_consumed' => nil)
  end

  it 'keeps local smoke bootstrap disabled despite inherited opt-in settings' do
    stdout, stderr, status = run_smoke('AWS_BOOTSTRAP_ENABLED' => 'true', 'RUNTIME_SMOKE_FIXTURE' => 'ambient')

    expect(status.success?).to be(true), "#{stdout}\n#{stderr}"
    expect(JSON.parse(stdout).dig('runtime_smoke_result', 'aws')).to eq(
      'bootstrap_enabled' => 'false', 'stub_responses' => true, 'requests' => [], 'fixture_consumed' => nil
    )
  end

  def run_authored_bootstrap
    code = <<~RUBY
      require #{harness.inspect}
      DependencySmoke.configure_environment
      DependencySmoke.configure_aws
      require #{File.join(root, 'lib/aws_bootstrap').inspect}
      AwsBootstrap.load!(environment: 'production', asset_compilation: false)
      expected = DependencySmoke::FIXTURE.dig('aws', 'secretsmanager', 'get_secret_value', 'secret_string')
      puts JSON.generate(ssm_consumed: ENV['RUNTIME_SMOKE_FIXTURE'] == 'authored-local-only',
                         secret_consumed: ENV['SECRET_KEY_BASE'] == expected,
                         aws_requests: DependencySmoke.aws_requests)
    RUBY
    overrides = image_environment.merge('BUNDLE_DEPLOYMENT' => nil, 'BUNDLE_PATH' => ENV.fetch('BUNDLE_PATH', nil),
                                        'BUNDLE_WITHOUT' => nil, 'RUBYOPT' => nil, 'BUNDLER_SETUP' => nil)
    Open3.capture3(environment.merge(overrides), RbConfig.ruby, '-rbundler/setup', '-e', code, chdir: root)
  end

  it 'consumes authored SSM and exact secret responses through the production bootstrap' do
    stdout, stderr, status = run_authored_bootstrap
    expect(status.success?).to be(true), "#{stdout}\n#{stderr}"
    expect(JSON.parse(stdout)).to eq('ssm_consumed' => true, 'secret_consumed' => true, 'aws_requests' => {
      'ssm.get_parameters_by_path' => 1, 'cloudformation.list_exports' => 1,
      'secretsmanager.list_secrets' => 1, 'secretsmanager.get_secret_value' => 1
    })
  end

  it 'boots with the selected Ruby and actual mysql2 and bootsnap native extensions' do
    stdout, stderr, status = run_smoke
    expect(status.success?).to be(true), "#{stdout}\n#{stderr}"
    result = JSON.parse(stdout).fetch('runtime_smoke_result')
    expect(result.dig('runtime', 'ruby')).to eq(File.read(File.join(root, '.ruby-version')).strip)
    expect(result.dig('runtime', 'extensions').keys).to contain_exactly('mysql2', 'bootsnap')
    result.dig('runtime', 'extensions').each do |name, extension|
      expect(extension.fetch('path')).to match(%r{/#{name}/#{name}\.(?:so|bundle)\z})
      expect(extension.fetch('sha256')).to eq(Digest::SHA256.file(extension.fetch('path')).hexdigest)
    end
  end

  {
    'non-test Rails environment' => [{ 'RAILS_ENV' => 'production' }, 'RAILS_ENV must be test'],
    'non-test Rack environment' => [{ 'RACK_ENV' => 'staging' }, 'RACK_ENV must be test'],
    'application database namespace' => [{ 'DATABASE_NAME' => 'railsdb' }, 'Unsafe database namespace'],
    'remote database host' => [{ 'PRIMARY_DB_HOST' => 'production.example.com' }, 'Unsafe database host'],
    'remote replica host' => [{ 'DATABASE_REPLICA_HOST' => 'production.example.com' }, 'Unsafe replica host'],
    'default application database port' => [{ 'DATABASE_PORT' => '3306' }, 'Explicit isolated database port required'],
    'database IAM configuration' => [{ 'DATABASE_IAM_AUTH' => 'true' }, 'Database IAM/SSL options forbidden'],
    'database SSL configuration' => [{ 'DATABASE_SSL' => 'true' }, 'Database IAM/SSL options forbidden'],
    'primary database URL' => [{ 'DATABASE_URL' => 'mysql2://production.example.com/railsdb' }, 'Database URLs are forbidden'],
    'queue database URL' => [{ 'QUEUE_DATABASE_URL' => 'mysql2://production.example.com/railsdb_queue' }, 'Database URLs are forbidden'],
    'incomplete database isolation inputs' => [{ 'RUNTIME_SMOKE_DB' => '1' }, 'Database mode requires explicit isolation inputs']
  }.each do |description, (overrides, rejection)|
    it "rejects #{description} before Rails boot" do
      stdout, stderr, status = run_smoke(overrides)
      expect(status.success?).to be(false)
      expect(stdout).not_to include('runtime_smoke_result')
      expect(stderr).to include("RUNTIME_SMOKE_FAILURE=RuntimeError: #{rejection}")
      expect(stderr).not_to include('config/environment', 'Mysql2::Error')
    end
  end

  {
    'test Rails environment' => [{ 'RAILS_ENV' => 'test' }, 'RAILS_ENV must be production'],
    'test Rack environment' => [{ 'RACK_ENV' => 'test' }, 'RACK_ENV must be production'],
    'database-free mode' => [{ 'RUNTIME_SMOKE_DB' => '0' }, 'Runtime image smoke requires database mode'],
    'missing isolation password' => [{ 'DATABASE_PASSWORD' => nil }, 'Database mode requires explicit isolation inputs'],
    'dummy secret flag' => [{ 'SECRET_KEY_BASE_DUMMY' => '1' }, 'Dummy secret flag forbidden'],
    'extra test group' => [{ 'RAILS_GROUPS' => 'test' }, 'Extra Rails groups forbidden'],
    'non-deployment bundle' => [{ 'BUNDLE_DEPLOYMENT' => '0' }, 'Production runtime bundle required'],
    'different bundle path' => [{ 'BUNDLE_PATH' => '/tmp/bundle' }, 'Production runtime bundle required'],
    'different excluded groups' => [{ 'BUNDLE_WITHOUT' => 'development' }, 'Production runtime bundle required'],
    'remote image database' => [{ 'PRIMARY_DB_HOST' => 'production.example.com' }, 'Unsafe database host']
  }.each do |description, (overrides, rejection)|
    it "rejects runtime image #{description} before Rails boot" do
      # Reject image-only settings before host Bundler's inherited setup prelude.
      stdout, stderr, status = run_smoke(image_environment.merge(overrides).merge('RUBYOPT' => nil, 'BUNDLER_SETUP' => nil))
      expect(status.success?).to be(false)
      expect(stdout).not_to include('runtime_smoke_result')
      expect(stderr).to include("RUNTIME_SMOKE_FAILURE=RuntimeError: #{rejection}")
      expect(stderr).not_to include('config/environment', 'Mysql2::Error')
    end
  end
end
