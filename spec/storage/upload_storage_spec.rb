# frozen_string_literal: true

require 'spec_helper'
require 'pathname'
require 'erb'
require 'yaml'
require 'rake'
require_relative '../../lib/upload_storage'

RSpec.describe UploadStorage do
  let(:settings) do
    { 'ACTIVE_STORAGE_STAGING_BUCKET' => 'synthetic-staging-uploads',
      'ACTIVE_STORAGE_PRODUCTION_BUCKET' => 'synthetic-production-uploads',
      'ACTIVE_STORAGE_S3_REGION' => 'us-east-1' }
  end

  it 'uses distinct deployed services independently of disabled AWS bootstrap' do
    expect(described_class.service_for('staging', env: settings.merge('AWS_BOOTSTRAP_ENABLED' => 'false'))).to eq(:staging_uploads)
    expect(described_class.service_for('production', env: settings.merge('AWS_BOOTSTRAP_ENABLED' => 'false'))).to eq(:production_uploads)
  end

  invalid_values = [nil, '', " \t "].freeze
  %w[staging production].each do |environment|
    ["ACTIVE_STORAGE_#{environment.upcase}_BUCKET", 'ACTIVE_STORAGE_S3_REGION'].each do |variable|
      invalid_values.each do |value|
        it "rejects #{environment} #{variable} set to #{value.inspect} without a Disk fallback" do
          expect { described_class.service_for(environment, env: settings.merge(variable => value)) }
            .to raise_error(UploadStorage::ConfigurationError, /#{variable}/)
        end
      end
    end
  end

  it 'does not treat a dummy secret in a normal deployed process as the asset task' do
    expect { described_class.service_for('production', env: { 'SECRET_KEY_BASE_DUMMY' => '1' }) }
      .to raise_error(UploadStorage::ConfigurationError)
  end

  it 'only exempts the exact asset task and constructs a real inert adapter that refuses uploads' do
    previous = Rake.application
    Rake.application = Rake::Application.new
    Rake.application.init('rake', ['assets:precompile'])
    expect(described_class.service_for('production', env: { 'SECRET_KEY_BASE_DUMMY' => '1' })).to eq(:upload_build_only)
    adapter = ActiveStorage::Service::UploadBuildOnlyService.new
    expect { adapter.upload('synthetic', StringIO.new('bytes')) }.to raise_error(ActiveStorage::Service::UploadBuildOnlyService::Unavailable)
    expect { adapter.download('synthetic') }.to raise_error(ActiveStorage::Service::UploadBuildOnlyService::Unavailable)
    Rake.application.init('rake', ['assets:precompile', 'server'])
    expect { described_class.service_for('production', env: { 'SECRET_KEY_BASE_DUMMY' => '1' }) }
      .to raise_error(UploadStorage::ConfigurationError)
  ensure
    Rake.application = previous
  end
end
