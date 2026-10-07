# frozen_string_literal: true

# Dedicated counters cannot be evicted or cleared by the general application cache.
class RequestRateLimitCounter < CacheRecord
  # @param key [String] namespaced SHA-256 digest
  # @param expires_at [Integer] fixed expiry in epoch seconds
  # @return [Integer] committed atomic aggregate count
  def self.increment_key(key, expires_at:)
    transaction do
      materialize(key, expires_at)
      counter = lock.find_by!(counter_key: key)
      raise RequestRateLimitStore::Unavailable, 'Expired counter bucket' if counter.expires_at <= Time.now.to_i

      count = counter.count + 1
      counter.update!(count: count)
      count
    end
  end

  # @param before [Integer] epoch seconds, default current time
  # @param limit [Integer] bounded batch
  # @return [Integer] expired rows deleted; active counters survive
  def self.prune_expired(before: Time.now.to_i, limit: 1000)
    raise ArgumentError, 'Invalid pruning batch' unless limit.is_a?(Integer) && limit.between?(1, 1000)

    where(expires_at: ..before).limit(limit).delete_all
  end

  # @param key [String]
  # @param expires_at [Integer]
  # @return [void] unique insert/upsert takes the conflicting InnoDB exclusive lock
  def self.materialize(key, expires_at)
    connection_pool.with_connection do |connection|
      sql = 'INSERT INTO request_rate_limit_counters (counter_key, count, expires_at, created_at, updated_at) ' \
            "VALUES (#{connection.quote(key)}, 0, #{Integer(expires_at)}, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)) " \
            'ON DUPLICATE KEY UPDATE counter_key = counter_key'
      connection.execute(sql)
    end
  end
  private_class_method :materialize
end
