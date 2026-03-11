# frozen_string_literal: true

# Job to publish custom metrics to AWS CloudWatch.
# This job is responsible for sending metrics, such as queue depths or job performance stats,
# to AWS CloudWatch for monitoring and alerting.

require 'aws-sdk-cloudwatch'

# Publishes custom metrics to AWS CloudWatch for monitoring.
class CloudWatchService
  def initialize
    @cloudwatch = Aws::CloudWatch::Client.new(region: 'us-east-1')
  end

  # Sends a single count metric data point to CloudWatch.
  #
  # @param namespace [String] CloudWatch namespace for grouping metrics
  # @param metric_name [String] the metric identifier
  # @param value [Numeric] the count value to publish
  # @return [void]
  def publish_metric(namespace, metric_name, value)
    @cloudwatch.put_metric_data(
      namespace: namespace,
      metric_data: [
        {
          metric_name: metric_name,
          value: value,
          unit: 'Count'
        }
      ]
    )
  end
end
