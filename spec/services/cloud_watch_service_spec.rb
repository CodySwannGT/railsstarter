# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/synthetic_aws'
require 'rails_helper'

RSpec.describe CloudWatchService do
  let(:client) { Aws::CloudWatch::Client.new(region: 'us-east-1', stub_responses: true) }

  before do
    allow(Aws::CloudWatch::Client).to receive(:new).with(region: 'us-east-1').and_return(client)
  end

  it 'sends a count metric through the installed SDK with exact namespace, name and value' do
    client.stub_responses(:put_metric_data, {})

    described_class.new.publish_metric('Synthetic/Queue', 'SyntheticPendingJobs', 7)

    expect(client.api_requests.map { |request| request.slice(:operation_name, :params) }).to eq([
                                                                                                  { operation_name: :put_metric_data,
                                                                                                    params: { namespace: 'Synthetic/Queue',
                                                                                                              metric_data: [{ metric_name: 'SyntheticPendingJobs', value: 7, unit: 'Count' }] } }
                                                                                                ])
  end

  it 'propagates a real SDK service error for the job to handle' do
    client.stub_responses(:put_metric_data, 'InternalServiceError')

    expect { described_class.new.publish_metric('Synthetic/Queue', 'SyntheticPendingJobs', 0) }
      .to raise_error(Aws::CloudWatch::Errors::InternalServiceError)
    expect(client.api_requests.pluck(:operation_name)).to eq([:put_metric_data])
  end
end
