# frozen_string_literal: true

require 'ipaddr'
require_relative 'deployed_host_policy'

# Explicit quota and ingress configuration; deployments must choose their topology.
class RequestPolicy
  # @param env [Hash, ENV]
  # @param environment [String]
  def initialize(env = ENV, environment: 'development')
    @settings = {
      limit: positive_integer(env, 'REQUEST_RATE_LIMIT', '120'),
      period: positive_integer(env, 'REQUEST_RATE_PERIOD', '60'),
      enabled: enabled_setting?(env) && !DeployedHostPolicy.asset_build?(env),
      ingress: ingress_setting(env, environment),
      thruster_peers: peers(env, 'THRUSTER_TRUSTED_PEERS'),
      alb_peers: peers(env, 'ALB_TRUSTED_PEERS')
    }.freeze
    validate_peers
  end

  # @return [Integer]
  def limit = @settings.fetch(:limit)
  # @return [Integer]
  def period = @settings.fetch(:period)
  # @return [String]
  def ingress = @settings.fetch(:ingress)
  # @return [Boolean]
  def enabled? = @settings.fetch(:enabled)
  # @return [Array<IPAddr>]
  def thruster_peers = @settings.fetch(:thruster_peers)
  # @return [Array<IPAddr>]
  def alb_peers = @settings.fetch(:alb_peers)

  private

  def positive_integer(env, name, fallback)
    value = env.fetch(name, fallback)
    raise ArgumentError, "#{name} must be a positive decimal integer" unless value.match?(/\A[1-9]\d*\z/)

    Integer(value, 10)
  end

  def enabled_setting?(env)
    value = env.fetch('REQUEST_RATE_LIMIT_ENABLED', 'true')
    raise ArgumentError, 'REQUEST_RATE_LIMIT_ENABLED must be true or false' unless %w[true false].include?(value)

    value == 'true'
  end

  def ingress_setting(env, environment)
    value = env['REQUEST_INGRESS_PROFILE']
    value = nil if value.to_s.empty?
    value ||= 'direct' unless %w[staging production].include?(environment) && !DeployedHostPolicy.asset_build?(env)
    raise ArgumentError, 'REQUEST_INGRESS_PROFILE must be direct, thruster, alb or alb_thruster' unless %w[direct thruster alb alb_thruster].include?(value)

    value
  end

  def peers(env, name)
    raw = env[name]
    return [] if raw.to_s.strip.empty?

    raw.split(',', -1).map do |token|
      address = IPAddr.new(token.strip)
      raise ArgumentError if address.prefix.zero?

      address
    end.freeze
  rescue ArgumentError
    raise ArgumentError, "#{name} must contain explicit IP addresses or nonzero CIDRs", cause: nil
  end

  def validate_peers
    raise ArgumentError, 'THRUSTER_TRUSTED_PEERS is required' if %w[thruster alb_thruster].include?(ingress) && thruster_peers.empty?
    raise ArgumentError, 'ALB_TRUSTED_PEERS is required' if %w[alb alb_thruster].include?(ingress) && alb_peers.empty?
  end
end
