# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'
require 'rbconfig'
require 'aws-sdk-ssm'

RSpec.context 'when isolating terminal SDK HTTP' do
  let(:boundary) { File.expand_path('../../test/runtime/dependency_upgrade/sdk_boundary.rb', __dir__) }

  def sdk_control
    <<~RUBY
      require #{boundary.inspect}
      settings = { region: 'us-east-1', credentials: Aws::Credentials.new('synthetic', 'synthetic') }
      stub = Aws::SSM::Client.new(**settings, stub_responses: true)
      stub.stub_responses(:get_parameters_by_path, parameters: [{name: '/synthetic/key', value: 'payload'}])
      response = stub.get_parameters_by_path(path: '/synthetic/')
      puts JSON.generate(payload: response.parameters.first.value, recorded: stub.api_requests.first[:params])
      begin
        Aws::SSM::Client.new(**settings, stub_responses: false, retry_limit: 0,
                            endpoint: 'http://127.0.0.1:1').get_parameters_by_path(path: '/synthetic/')
        abort 'negative control missed terminal transport'
      rescue DependencySdkBoundary::TransportForbidden => error
        warn error.message
      end
    RUBY
  end

  it 'consumes serialized native SDK stubs and rejects a nonstubbed SSM request before HTTP' do
    environment = ENV.keys.grep(/\AAWS_/).index_with { |_key| nil }
    environment.merge!('AWS_CONFIG_FILE' => File::NULL, 'AWS_SHARED_CREDENTIALS_FILE' => File::NULL,
                       'AWS_EC2_METADATA_DISABLED' => 'true')
    output, error, status = Open3.capture3(environment, RbConfig.ruby, '-rjson', '-rbundler/setup', '-e', sdk_control)
    expect(status.success?).to be(true), "#{output}\n#{error}"
    expect(JSON.parse(output)).to eq('payload' => 'payload', 'recorded' => { 'path' => '/synthetic/' })
    expect(error).to include('Terminal SDK HTTP forbidden: get_parameters_by_path')
  end
end
