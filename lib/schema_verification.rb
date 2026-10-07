# frozen_string_literal: true

require_relative 'generated_schema_tables'

# Compare the configured application dump with the primary connection's tables.
class SchemaVerification
  # Rails bookkeeping tables omitted from both expected and actual application-table lists.
  RAILS_INTERNALS = %w[schema_migrations ar_internal_metadata].freeze

  def initialize(expected, actual)
    @expected = expected - RAILS_INTERNALS
    @actual = actual - RAILS_INTERNALS
  end

  # Compare filtered table sets without querying or changing the database or migration state.
  # pending_migrations is a fixed false receipt field, not a live migration-status probe.
  # @return [Hash{Symbol => Object}] pass/fail, counts, sorted missing/extra names, and fixed flag
  def result
    missing = (@expected - @actual).sort
    extra = (@actual - @expected).sort
    { status: missing.empty? && extra.empty? ? 'pass' : 'fail',
      expected_count: @expected.size, actual_count: @actual.size,
      missing: missing, extra: extra, pending_migrations: false }
  end
end
