# frozen_string_literal: true

# Publishes pending background job count to AWS CloudWatch.
class PublishCloudWatchMetricsJob < ApplicationJob
  queue_as :default

  # @return [void]
  def perform(*_args)
    logger.debug 'PublishCloudWatchMetricsJob works...'
    pending_count = SolidQueueJob.unfinished_count
    logger.debug { "There are #{pending_count} pending background jobs." }
    CloudWatchService.new.publish_metric('Railsstarter/BackgroundJobs', 'PendingJobs', pending_count)
  rescue StandardError => error
    logger.error error.message
  end
end
