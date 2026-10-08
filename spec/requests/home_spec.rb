# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/synthetic_aws'
require 'rails_helper'

RSpec.describe 'Application endpoints', type: :request do
  it 'renders the real home page inside the application layout' do
    get '/'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Welcome to Your Project', 'Your Rails 8.1 application is running.')
    expect(response.body).to include('<html lang="en">', 'Version', APP_VERSION, '(Test)')
    expect(response.body).not_to include('id="flash-messages"')
  end

  it 'serves the Rails health endpoint' do
    get '/up'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('background-color: green')
  end

  it 'rejects browsers outside the application modern-browser policy' do
    get '/', headers: { 'HTTP_USER_AGENT' => 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)' }

    expect(response).to have_http_status(:not_acceptable)
  end

  it 'boots the local test application without AWS requests or bootstrap opt-in' do
    expect(ENV.fetch('AWS_BOOTSTRAP_ENABLED', nil)).not_to eq('true')
    expect(SyntheticAws.boot_requests).to be_empty
    expect(ENV.fetch('AWS_EC2_METADATA_DISABLED')).to eq('true')
    expect(Aws.config[:credentials].access_key_id).to eq('synthetic-access-key')
  end

  it 'preserves the explicitly authored database endpoint for every test role' do
    endpoint = SyntheticAws::DATABASE_ENDPOINT
    replica_host = endpoint.fetch('DATABASE_REPLICA_HOST', endpoint.fetch('PRIMARY_DB_HOST'))
    expect(ENV.slice(*endpoint.keys)).to eq(endpoint)
    suffixes = { 'primary' => '_test', 'primary_replica' => '_test', 'queue' => '_queue_test',
                 'cable' => '_cable_test', 'cache' => '_cache_test' }
    configs = ActiveRecord::Base.configurations.configs_for(env_name: 'test', include_hidden: true)
    expect(configs.map(&:name)).to match_array(suffixes.keys)
    configs.each do |config|
      expect(config.configuration_hash.slice(:host, :port, :database)).to eq(
        host: config.name == 'primary_replica' ? replica_host : endpoint.fetch('PRIMARY_DB_HOST'),
        port: Integer(endpoint.fetch('DATABASE_PORT')),
        database: "#{endpoint.fetch('DATABASE_NAME')}#{suffixes.fetch(config.name)}"
      )
    end
  end
end
