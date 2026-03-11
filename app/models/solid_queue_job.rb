# frozen_string_literal: true

# Read-only model for querying Solid Queue job counts (monitoring).
class SolidQueueJob < ApplicationRecord
  self.abstract_class = true
  connects_to database: { writing: :queue, reading: :queue }
  self.table_name = 'solid_queue_jobs'

  # Returns the number of jobs that have not yet completed, for dashboard monitoring.
  #
  # @return [Integer]
  def self.unfinished_count
    where(finished_at: nil).count
  end
end
