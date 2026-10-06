# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/synthetic_aws'
require 'rails_helper'

RSpec.describe ApplicationJob do
  before do
    stub_const('SyntheticFailureJob', Class.new(described_class) do
      def perform(message)
        raise ActiveRecord::Deadlocked, message
      end
    end)
    SyntheticFailureJob.queue_adapter = :test
  end

  it 'retries database deadlocks using the test adapter with delayed execution' do
    SyntheticFailureJob.perform_now('synthetic deadlock')

    expect(SyntheticFailureJob.queue_adapter.enqueued_jobs.size).to eq(1)
    expect(SyntheticFailureJob.queue_adapter.enqueued_jobs.first[:at]).to be > Time.current.to_f
  end

  it 're-raises a deadlock after the fifth execution rather than retrying forever' do
    job = SyntheticFailureJob.new('synthetic deadlock')
    job.exception_executions['[ActiveRecord::Deadlocked]'] = 4

    expect { job.perform_now }.to raise_error(ActiveRecord::Deadlocked, 'synthetic deadlock')
    expect(SyntheticFailureJob.queue_adapter.enqueued_jobs).to be_empty
  end

  it 'discards arguments whose referenced records can no longer be deserialized' do
    payload = SyntheticFailureJob.new.serialize
    payload['arguments'] = [{ '_aj_globalid' => 'gid://app/SyntheticMissingRecord/123' }]

    expect { SyntheticFailureJob.execute(payload) }.not_to raise_error
    expect(SyntheticFailureJob.queue_adapter.enqueued_jobs).to be_empty
  end
end
