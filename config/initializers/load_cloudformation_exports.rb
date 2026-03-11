# frozen_string_literal: true

require 'aws-sdk-cloudformation'

def fetch_cloudformation_exports
  client = begin
    Aws::CloudFormation::Client.new(region: 'us-east-1')
  rescue StandardError
    nil
  end

  # List all exports and store them in a hash
  begin
    client.list_exports.exports.each_with_object({}) do |export, hash|
      hash[export.name] = export.value
    end
  rescue StandardError
    nil
  end
end

exports = fetch_cloudformation_exports

if exports
  # Set CLOUDFRONT_ENDPOINT to the first key starting with 'assetDomain'
  ENV['CLOUDFRONT_ENDPOINT'] ||= exports.find { |key, _| key.start_with?('assetDomain') }&.last
  ENV['REDIS_CACHE_ENDPOINT_URL'] ||= exports['redisCacheEndpointUrl']
  ENV['REDIS_CACHE_PORT'] ||= exports['redisCachePort']
  ENV['DEFAULT_QUEUE_URL'] ||= exports['QueueUrl']
  ENV['EMAIL_QUEUE_URL'] ||= exports['EmailQueueUrl']
  ENV['CENSUS_QUEUE_URL'] ||= exports['CensusQueueUrl']
end
