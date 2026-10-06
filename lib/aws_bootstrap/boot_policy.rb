# frozen_string_literal: true

# Loads remote configuration under the application's explicit boot policy.
class AwsBootstrap
  # Decide whether remote configuration is needed before any clients are built.
  class BootPolicy
    def initialize(environment:, env:, asset_compilation:)
      @environment = environment
      @env = env
      @asset_compilation = asset_compilation
      @deployment = {}
    end

    def enabled?
      return false if @env['SECRET_KEY_BASE_DUMMY']
      return false if @asset_compilation && @env['AWS_BOOTSTRAP_ENABLED'] != 'true'

      enabled = @env.fetch('AWS_BOOTSTRAP_ENABLED', deployed? ? 'true' : 'false')
      raise Error, 'AWS bootstrap: AWS_BOOTSTRAP_ENABLED must be true or false' unless %w[true false].include?(enabled)

      enabled == 'true'
    end

    def deployed?
      @deployment.fetch(:deployed) do
        @deployment[:deployed] = %w[production staging].include?(@environment.to_s)
      end
    end
  end
end
