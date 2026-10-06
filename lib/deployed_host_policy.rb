# frozen_string_literal: true

require 'ipaddr'
require 'uri'

# Exact deployed host identities, independent of throttle and client-IP policy.
module DeployedHostPolicy
  class << self
    # @param env [Hash, ENV]
    # @return [Array<String>] normalized exact identities; Rails permits request ports
    def hosts(env = ENV)
      raw = env['ALLOWED_HOSTS']
      raise ArgumentError, 'ALLOWED_HOSTS must contain explicit host identities' if raw.to_s.strip.empty?

      raw.split(',', -1).map do |value|
        host = value.strip.downcase
        raise ArgumentError, 'ALLOWED_HOSTS contains an invalid host identity' unless valid_host?(host)

        host
      end.uniq
    end

    # @param env [Hash, ENV]
    # @return [String, nil] one HTTPS asset origin, never a broad scheme grant
    def asset_origin(env = ENV)
      value = env['CLOUDFRONT_ENDPOINT']
      return if [nil, ''].include?(value)

      uri = URI.parse(value)
      raise ArgumentError, 'CLOUDFRONT_ENDPOINT must be an HTTPS origin' unless valid_asset_origin?(uri)

      port = uri.port
      "https://#{uri.host}#{":#{port}" unless port == 443}"
    rescue URI::InvalidURIError
      raise ArgumentError, 'CLOUDFRONT_ENDPOINT must be an HTTPS origin', cause: nil
    end

    # An ENV dummy key alone, runner or mixed task invocation is never a bypass.
    # @param env [Hash, ENV]
    # @return [Boolean]
    def asset_build?(env = ENV)
      return false unless env['SECRET_KEY_BASE_DUMMY'] == '1' && defined?(Rake::Application)

      Rake.application.top_level_tasks == ['assets:precompile']
    end

    # @param config [Rails::Application::Configuration]
    # @param env [Hash, ENV]
    # @return [void]
    def configure(config, env = ENV)
      config.hosts = env['ALLOWED_HOSTS'].to_s.strip.empty? && asset_build?(env) ? [] : hosts(env)
      exact_health = ->(request) { request.path == '/up' }
      config.host_authorization = config.host_authorization.merge(exclude: exact_health)
      ssl = config.ssl_options
      config.ssl_options = ssl.merge(redirect: ssl.fetch(:redirect, {}).merge(exclude: exact_health))
    end

    private

    def valid_asset_origin?(uri)
      forbidden_components = [uri.userinfo, uri.query, uri.fragment].compact
      uri.is_a?(URI::HTTPS) && forbidden_components.empty? &&
        ['', '/'].include?(uri.path) && valid_host?(uri.host.to_s) && uri.port.between?(1, 65_535)
    end

    def valid_host?(host)
      return false if host.empty? || host.bytesize > 253
      return ipv6?(host) if host.start_with?('[')
      return ipv4?(host) if host.match?(/\A[\d.]+\z/)

      host.split('.', -1).all? { |label| label.match?(/\A[a-z\d](?:[a-z\d-]{0,61}[a-z\d])?\z/) }
    end

    def ipv4?(host)
      address = IPAddr.new(host)
      address.ipv4? && address.to_s == host
    rescue IPAddr::InvalidAddressError
      false
    end

    def ipv6?(host)
      host.match?(/\A\[[0-9a-f:.]+\]\z/) && IPAddr.new(host[1...-1]).ipv6?
    rescue IPAddr::InvalidAddressError
      false
    end
  end
end
