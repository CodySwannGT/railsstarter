# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/synthetic_aws'
require 'rails_helper'

RSpec.describe ApplicationRecord, type: :model do
  # Transactional fixtures intentionally share the writer pool with the reader.
  # This read-only example checks the application's actual role configuration.
  self.use_transactional_tests = false

  it 'routes the writing role to primary and reading role to the primary replica' do
    expect(described_class.connected_to(role: :writing) { described_class.connection_db_config.name }).to eq('primary')
    expect(described_class.connected_to(role: :reading) { described_class.connection_db_config.name })
      .to eq('primary_replica')
  end
end
