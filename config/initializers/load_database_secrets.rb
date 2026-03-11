# frozen_string_literal: true

require 'aws-sdk-secretsmanager'
require 'json'

def fetch_database_secrets
  client = begin
    Aws::SecretsManager::Client.new(region: 'us-east-1')
  rescue StandardError
    nil
  end

  # List all secrets and filter by name prefix
  if client
    secrets = begin
      client.list_secrets
    rescue StandardError
      nil
    end
    secret = secrets.secret_list.find { |s| s.name.start_with?('PipelineStack') } if secrets
  end

  return unless secret

  secret_value = client.get_secret_value(secret_id: secret.name)
  JSON.parse(secret_value.secret_string)
end

unless ENV['DATABASE_USER']

  secrets = fetch_database_secrets

  if secrets
    ENV['DATABASE_USER'] = secrets['username']
    ENV['DATABASE_PASSWORD'] = secrets['password']
    ENV['DATABASE_NAME'] = secrets['dbname']
    ENV['PRIMARY_DB_HOST'] = secrets['host']
    ENV['DB_PORT'] = secrets['port'].to_s
    # Assuming DATABASE_REPLICA_HOST follows a pattern based on PRIMARY_DB_HOST
    ENV['DATABASE_REPLICA_HOST'] = secrets['host'].gsub('.cluster-', '.cluster-ro-')
  end
end
