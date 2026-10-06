# frozen_string_literal: true

# Required before rails_helper so initializers use the real SDK's response stubs.
require 'aws-sdk-cloudwatch'
require 'aws-sdk-cloudformation'
require 'aws-sdk-secretsmanager'
require 'aws-sdk-ssm'

module SyntheticAws
  DATABASE_ENDPOINT = ENV.slice('PRIMARY_DB_HOST', 'DATABASE_REPLICA_HOST', 'DATABASE_PORT', 'DATABASE_NAME').freeze

  def self.boot_requests
    @boot_requests ||= []
  end

  def self.boot_response(operation, response)
    lambda do |context|
      boot_requests << { operation: operation, params: context.params.dup }
      response
    end
  end
end

ENV['AWS_EC2_METADATA_DISABLED'] = 'true'
Aws.config.update(
  credentials: Aws::Credentials.new('synthetic-access-key', 'synthetic-secret-key'),
  region: 'us-east-1',
  stub_responses: true,
  ssm: {
    stub_responses: {
      get_parameters_by_path: SyntheticAws.boot_response(:get_parameters_by_path, { parameters: [] })
    }
  },
  cloudformation: {
    stub_responses: { list_exports: SyntheticAws.boot_response(:list_exports, { exports: [] }) }
  },
  secretsmanager: {
    stub_responses: { list_secrets: SyntheticAws.boot_response(:list_secrets, { secret_list: [] }) }
  }
)
