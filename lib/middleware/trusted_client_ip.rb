# frozen_string_literal: true

require 'ipaddr'
require 'json'

# Rack middleware for request policy and trusted ingress identity.
module Middleware
  # Canonical identity used directly by RackAttack, independent of Rails remote_ip.
  class TrustedClientIp
    # Signals a malformed client address or forwarding chain.
    class InvalidClient < StandardError; end
    # Signals that a forwarding peer is outside the configured trusted ranges.
    class UntrustedPeer < StandardError; end

    # @param app [Object]
    # @param policy [RequestPolicy]
    def initialize(app, policy)
      @app = app
      @policy = policy
    end

    # @param env [Hash]
    # @return [Array] actual Rack response, fail closed on quota-store failures
    def call(env)
      env['request_policy.health'] = env['PATH_INFO'] == '/up'
      env['request_policy.client_ip'] = client_address(env).to_s unless env['request_policy.health']
      @app.call(env)
    rescue InvalidClient
      failure(400, 'invalid_client_identity')
    rescue UntrustedPeer
      failure(403, 'untrusted_ingress_peer')
    rescue RequestRateLimitStore::Unavailable, Rack::Attack::MissingStoreError, Rack::Attack::MisconfiguredStoreError
      failure(503, 'request_limit_store_unavailable')
    end

    private

    def client_address(env)
      peer = parse_address(env.fetch('REMOTE_ADDR', ''))
      ingress = @policy.ingress
      return peer if ingress == 'direct'

      validate_peer(peer, ingress == 'alb' ? @policy.alb_peers : @policy.thruster_peers)
      parse_address(forwarded_client(env))
    end

    def forwarded_client(env)
      chain = env.fetch('HTTP_X_FORWARDED_FOR', '').split(',', -1)
      return chain.fetch(-1, '') unless @policy.ingress == 'alb_thruster'

      raise InvalidClient if chain.length < 2

      validate_peer(parse_address(chain.last), @policy.alb_peers)
      chain[-2]
    end

    def validate_peer(address, ranges)
      raise UntrustedPeer unless ranges.any? { |range| range.include?(address) }
    end

    def parse_address(raw)
      token = raw.strip
      validate_token(token)

      address, port = address_and_port(token)
      raise InvalidClient if port && !Integer(port, 10).between?(1, 65_535)

      IPAddr.new(address).native
    rescue ArgumentError
      raise InvalidClient, cause: nil
    end

    def validate_token(token)
      raise InvalidClient unless token.match?(%r{\A[^/\s%]+\z})
    end

    def address_and_port(token)
      bracketed = token.match(/\A\[([^\]]+)\](?::(\d+))?\z/)
      return bracketed.captures if bracketed

      ipv4_port = token.match(/\A([\d.]+):(\d+)\z/)
      ipv4_port ? ipv4_port.captures : [token, nil]
    end

    def failure(status, code)
      [status, { 'content-type' => 'application/json', 'cache-control' => 'no-store' }, [JSON.generate(error: code)]]
    end
  end
end
