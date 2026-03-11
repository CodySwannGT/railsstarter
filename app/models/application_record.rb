# frozen_string_literal: true

# Base model inherited by all application models.
#
# Provides multi-database routing (primary for writes, replica for reads).
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  connects_to database: { writing: :primary, reading: :primary_replica }
end
