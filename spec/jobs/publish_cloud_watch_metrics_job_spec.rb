# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/synthetic_aws'
require 'rails_helper'

RSpec.describe PublishCloudWatchMetricsJob do
  let(:client) { Aws::CloudWatch::Client.new(region: 'us-east-1', stub_responses: true) }
  let(:log_output) { StringIO.new }
  let(:job) { described_class.new }

  before do
    allow(Aws::CloudWatch::Client).to receive(:new).with(region: 'us-east-1').and_return(client)
    allow(job).to receive(:logger).and_return(ActiveSupport::Logger.new(log_output))
    allow(SolidQueueJob).to receive(:unfinished_count).and_return(3)
  end

  it 'publishes the unfinished count through CloudWatch and logs the observed count' do
    job.perform

    expect(client.api_requests.last[:params]).to eq(
      namespace: 'Your Project/BackgroundJobs',
      metric_data: [{ metric_name: 'PendingJobs', value: 3, unit: 'Count' }]
    )
    expect(log_output.string).to include('There are 3 pending background jobs.')
    expect(described_class.queue_name).to eq('default')
  end

  it 'logs a CloudWatch SDK failure without raising from the scheduled job' do
    client.stub_responses(:put_metric_data, 'InternalServiceError')

    expect { job.perform }.not_to raise_error
    expect(client.api_requests.pluck(:operation_name)).to eq([:put_metric_data])
    expect(log_output.string).to include('stubbed-response-error-message')
  end

  it 'logs a count failure and never attempts metric publication' do
    allow(SolidQueueJob).to receive(:unfinished_count).and_raise(StandardError, 'synthetic count failure')

    expect { job.perform }.not_to raise_error
    expect(client.api_requests).to be_empty
    expect(log_output.string).to include('synthetic count failure')
  end
end
