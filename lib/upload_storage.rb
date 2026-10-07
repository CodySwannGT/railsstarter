# frozen_string_literal: true

require 'json'

# User uploads use task-role credentials, independently of remote boot loading
# and asset publication. Unused service entries must still parse in local/test.
module UploadStorage
  # Raised when a selected deployed upload service lacks its required nonblank bucket/region.
  class ConfigurationError < StandardError; end

  # Bucket environment-variable lookup for the supported deployed upload configurations.
  BUCKET_VARIABLES = {
    'staging' => 'ACTIVE_STORAGE_STAGING_BUCKET',
    'production' => 'ACTIVE_STORAGE_PRODUCTION_BUCKET'
  }.freeze

  # Read bucket and region without constructing a provider client or validating nonblank values.
  # @param environment [String, Symbol] supported deployed upload configuration name
  # @param env [Hash, ENV] environment settings containing bucket/region values
  # @return [Hash{Symbol => String, nil}] bucket and region; absent settings remain nil
  # @raise [KeyError] environment is absent from the supported bucket lookup
  def self.configuration(environment, env: ENV)
    { bucket: env[BUCKET_VARIABLES.fetch(environment.to_s)], region: env['ACTIVE_STORAGE_S3_REGION'] }
  end

  def self.service_for(environment, env: ENV)
    environment = environment.to_s
    settings = configuration(environment, env: env)
    if asset_compilation?(env)
      require_relative 'active_storage/service/upload_build_only_service'
      return :upload_build_only
    end

    required = { BUCKET_VARIABLES.fetch(environment) => settings[:bucket], 'ACTIVE_STORAGE_S3_REGION' => settings[:region] }
    missing = required.select { |_, value| value.to_s.strip.empty? }.keys
    raise ConfigurationError, "Active Storage uploads require nonblank #{missing.join(', ')}" if missing.any?

    :"#{environment}_uploads"
  end

  def self.asset_compilation?(env = ENV)
    return false unless env['SECRET_KEY_BASE_DUMMY'] == '1'

    require 'rake'
    Rake.application.top_level_tasks == ['assets:precompile']
  end
end
