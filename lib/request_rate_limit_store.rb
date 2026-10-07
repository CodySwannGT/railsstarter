# frozen_string_literal: true

require 'digest'

# RackAttack increment contract: positive committed integer or controlled failure.
class RequestRateLimitStore
  # Raised for invalid increments/counts or unavailable/ambiguous database counter commits.
  class Unavailable < StandardError; end

  # @param namespace [String] stable application environment, not a process identity
  def initialize(namespace:)
    @namespace = namespace
  end

  # @param key [String]
  # @param amount [Integer]
  # @param expires_in [Integer]
  # @return [Integer] never nil or a write-one fallback
  def increment(key, amount, expires_in:)
    raise Unavailable, 'Invalid security counter operation' unless valid_increment?(amount, expires_in)

    count = RequestRateLimitCounter.increment_key(digest_key(key), expires_at: Time.now.to_i + expires_in)
    raise Unavailable, 'Invalid security count' unless count.is_a?(Integer) && count.positive?

    count
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionTimeoutError, ActiveRecord::StatementInvalid
    # A failed or ambiguous commit is never retried or reset to one.
    raise Unavailable, 'Security counter unavailable', cause: nil
  end

  # @param amount [Integer]
  # @param ttl [Integer]
  # @return [Boolean]
  def valid_increment?(amount, ttl) = 1.eql?(amount) && ttl.is_a?(Integer) && ttl.positive?
  private :valid_increment?

  # @param key [String]
  # @return [String] scoped non-sensitive physical key
  def digest_key(key) = Digest::SHA256.hexdigest("request-limit/v1/#{@namespace}/#{key}")
end
