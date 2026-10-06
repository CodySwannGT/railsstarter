# frozen_string_literal: true

# Bootsnap's ISeq initialization compiles Ruby before its coverage-aware fallback.
# Keep coverage enabled and use its supported compile-cache opt-out for RSpec.
ENV['DISABLE_BOOTSNAP_COMPILE_CACHE'] = '1'

require 'simplecov'
SimpleCov.start

RSpec.configure do |config|
  config.fail_if_no_examples = true
  config.before(:suite) do
    warn 'RSpec found zero examples. Check the spec path and filters before retrying.' if RSpec.world.example_count.zero?
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.order = :random

  Kernel.srand config.seed
end
