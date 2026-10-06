# frozen_string_literal: true

require 'json'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/enumerable'
require_relative 'aws_bootstrap/boot_policy'

# Loads remote configuration before Rails evaluates environment files or database.yml.
# Selectors are captured from the caller, and remote values only fill missing settings.
class AwsBootstrap
  # Sanitized boot failures deliberately exclude provider messages and secret values.
  class Error < StandardError; end

  # Environment settings and their default CloudFormation export names.
  EXPORTS = { 'CLOUDFRONT_ENDPOINT' => 'assetDomain' }.freeze
  # Environment settings mapped to fields of the selected database JSON secret.
  DATABASE_FIELDS = {
    'DATABASE_USER' => 'username', 'DATABASE_PASSWORD' => 'password',
    'DATABASE_NAME' => 'dbname', 'PRIMARY_DB_HOST' => 'host', 'DATABASE_PORT' => 'port'
  }.freeze

  # Load remote settings only when the boot policy enables it, preserving caller values.
  # @param environment [String, Symbol] Rails environment evaluated by the boot policy
  # @param env [Hash, ENV] mutable environment settings; selectors are captured before loading
  # @param asset_compilation [Boolean] whether argv identifies the assets:precompile task
  # @return [Hash, nil] loaded settings, or nil when the policy disables remote boot
  # @raise [Error] deployed settings are missing or remote configuration cannot be loaded safely
  def self.load!(environment:, env: ENV, asset_compilation: ARGV.include?('assets:precompile'))
    policy = BootPolicy.new(environment: environment, env: env, asset_compilation: asset_compilation)
    return unless policy.enabled?

    new(env, deployed: policy.deployed?).load
  end

  def initialize(env, deployed:)
    @env = env
    @original = env.to_h.dup.freeze
    @values = @original.dup
    @deployed = deployed
    @region = @original.fetch('AWS_REGION', @original.fetch('AWS_DEFAULT_REGION', 'us-east-1'))
  end

  def load
    load_parameters
    load_exports
    load_secrets
    raise Error, 'AWS bootstrap: required deployed configuration is missing' if @deployed && (DATABASE_FIELDS.keys + ['SECRET_KEY_BASE']).any? { |key| @values[key].to_s.empty? }

    @values.each { |key, value| @env[key] = value unless @original.key?(key) }
  end

  # Preserve the original public entry point; both operations fail visibly.
  alias load! load

  private

  def client(service)
    require "aws-sdk-#{service}"
    klass = { 'ssm' => Aws::SSM::Client, 'cloudformation' => Aws::CloudFormation::Client,
              'secretsmanager' => Aws::SecretsManager::Client }.fetch(service)
    klass.new(region: @region)
  rescue StandardError => error
    raise Error, "AWS bootstrap: client construction failed (#{error.class.name})", cause: nil
  end

  def pages(client, operation, collection, **arguments)
    rows = []
    each_page(client, operation, **arguments) { |response| rows.concat(response.public_send(collection)) }
    rows
  rescue Error
    raise
  rescue StandardError => error
    raise Error, "AWS bootstrap: #{operation} failed (#{error.class.name})", cause: nil
  end

  def each_page(client, operation, **arguments)
    token = nil
    seen = []
    loop do
      arguments[:next_token] = token if token
      response = client.public_send(operation, **arguments)
      yield response
      token = response.next_token
      break if token.blank?
      raise Error, "AWS bootstrap: #{operation} repeated pagination token" if seen.include?(token)

      seen << token
    end
  end

  def load_parameters
    path = ssm_path
    parameters = pages(client('ssm'), :get_parameters_by_path, :parameters,
                       path: "#{path}/", recursive: true, with_decryption: true)
    keys = []
    parameters.each do |parameter|
      name = parameter.name
      raise Error, 'AWS bootstrap: SSM parameter outside configured path' unless name.start_with?("#{path}/")

      key = name.delete_prefix("#{path}/").upcase.tr('/', '_')
      raise Error, 'AWS bootstrap: invalid or conflicting SSM environment key' unless key.match?(/\A[A-Z_][A-Z0-9_]*\z/) && keys.exclude?(key)

      keys << key
      @values[key] ||= parameter.value
    end
  end

  def ssm_path
    path = "/#{@original.fetch('AWS_SSM_PATH', '/app').split('/').reject(&:empty?).join('/')}"
    raise Error, 'AWS bootstrap: SSM path must not be root' if path == '/'

    path
  end

  def load_exports
    exports = pages(client('cloudformation'), :list_exports, :exports)
    EXPORTS.each do |key, default_name|
      next if @values.key?(key)

      name = @original.fetch("AWS_EXPORT_#{key}", default_name)
      matches = exports_named(exports, name)
      raise Error, 'AWS bootstrap: conflicting CloudFormation export' if matches.size > 1
      raise Error, 'AWS bootstrap: configured CloudFormation export is missing' if @original.key?("AWS_EXPORT_#{key}") && matches.empty?

      selected = matches.first
      @values[key] = selected.value if selected
    end
  end

  def exports_named(exports, name)
    exports.select { |export| export.name == name }
  end

  def load_secrets
    missing_database = DATABASE_FIELDS.keys.any? { |key| !@values.key?(key) }
    missing_key = !@values.key?('SECRET_KEY_BASE')
    return unless missing_database || missing_key

    secrets_client = client('secretsmanager')
    inventory = pages(secrets_client, :list_secrets, :secret_list)
    load_database(secret_value(secrets_client, select_secret(inventory, 'AWS_DATABASE_SECRET'))) if missing_database
    return unless missing_key

    @values['SECRET_KEY_BASE'] = secret_value(secrets_client, select_secret(inventory, 'AWS_SECRET_KEY_BASE_SECRET'))
  end

  def load_database(database)
    data = JSON.parse(database)
    raise Error, 'AWS bootstrap: database secret must be an object' unless data.is_a?(Hash)

    DATABASE_FIELDS.each { |key, field| @values[key] ||= data[field].to_s if data.key?(field) }
    host = @values['PRIMARY_DB_HOST']
    @values['DATABASE_REPLICA_HOST'] ||= host.gsub('.cluster-', '.cluster-ro-') if host
  rescue JSON::ParserError
    raise Error, 'AWS bootstrap: database secret is invalid JSON', cause: nil
  end

  def select_secret(inventory, selector)
    id = @original["#{selector}_ID"]
    matches = if id.present?
                inventory.select { |secret| secret.name == id || secret.arn == id }
              else
                select_prefix(inventory, @original["#{selector}_PREFIX"])
              end
    raise Error, 'AWS bootstrap: secret selection is missing or ambiguous' unless matches.size == 1

    selected = matches.first
    selected.arn || selected.name
  end

  def select_prefix(inventory, prefix)
    raise Error, 'AWS bootstrap: explicit secret identifier or prefix is required' if prefix.blank?

    inventory.select { |secret| secret.name.start_with?(prefix) }
  end

  def secret_value(client, id)
    client.get_secret_value(secret_id: id).secret_string || raise(Error, 'AWS bootstrap: secret string is missing')
  rescue Error
    raise
  rescue StandardError => error
    raise Error, "AWS bootstrap: get_secret_value failed (#{error.class.name})", cause: nil
  end
end
