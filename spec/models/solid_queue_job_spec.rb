# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/synthetic_aws'
require 'rails_helper'

RSpec.describe SolidQueueJob, type: :model do
  it 'counts unfinished queue rows and excludes completed rows using the queue database' do
    stub_const('SyntheticBaselineQueueRow', Class.new(described_class))
    now = Time.current
    attributes = { class_name: 'SyntheticBaselineJob', queue_name: 'synthetic-baseline',
                   created_at: now, updated_at: now }
    SyntheticBaselineQueueRow.create!(attributes.merge(finished_at: nil))
    SyntheticBaselineQueueRow.create!(attributes.merge(finished_at: nil))
    SyntheticBaselineQueueRow.create!(attributes.merge(finished_at: now))

    expect(described_class.unfinished_count).to eq(2)
    expect(described_class.connection_db_config.name).to eq('queue')
  end
end
