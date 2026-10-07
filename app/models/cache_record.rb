# frozen_string_literal: true

# Security counters always use the configured writable cache role, including test.
class CacheRecord < ApplicationRecord
  self.abstract_class = true
  connects_to database: { writing: :cache }
end
