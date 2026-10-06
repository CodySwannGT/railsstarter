# frozen_string_literal: true

# Bounded housekeeping deletes expired security counters only.
class PruneRequestRateLimitsJob < ApplicationJob
  queue_as :default

  # @return [Integer] number of expired rows removed in this invocation
  def perform
    count = RequestRateLimitCounter.prune_expired
    logger.info("Pruned #{count} expired request-limit counters")
    count
  end
end
