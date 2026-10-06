# frozen_string_literal: true

require 'aws-sdk-ssm'
require 'aws-sdk-cloudformation'
require 'aws-sdk-secretsmanager'

# rubocop:disable-next RSpec/DescribeClass -- The public interface is a Docker build.
RSpec.describe 'Credential-free asset compilation' do
  let(:root) { File.expand_path('../..', __dir__) }

  around do |example|
    previous = ENV.fetch('SECRET_KEY_BASE_DUMMY', nil)
    ENV['SECRET_KEY_BASE_DUMMY'] = '1'
    example.run
  ensure
    ENV['SECRET_KEY_BASE_DUMMY'] = previous
  end

  {
    'load_ssm_parameters.rb' => Aws::SSM::Client,
    'load_cloudformation_exports.rb' => Aws::CloudFormation::Client,
    'load_database_secrets.rb' => Aws::SecretsManager::Client
  }.each do |initializer, client|
    it "does not construct an AWS client through #{initializer} during dummy compilation" do
      allow(client).to receive(:new).and_raise('AWS client construction is forbidden during asset compilation')
      load File.join(root, 'config', 'initializers', initializer)
      expect(client).not_to have_received(:new)
    end
  end

  it 'compiles assets without network access or AWS build secrets' do
    dockerfile = File.read(File.join(root, 'Dockerfile'))
    expect(dockerfile).to match(/RUN --network=none .*SECRET_KEY_BASE_DUMMY=1 .*assets:precompile/)
    expect(dockerfile).not_to match(/awscli|aws configure|aws s3|aws_credentials|S3_BUCKET_NAME/)
    expect(File.read(File.join(root, 'worker.Dockerfile'))).not_to match(/awscli|aws configure|aws s3|aws_credentials|S3_BUCKET_NAME/)
  end
end
