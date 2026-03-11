# frozen_string_literal: true

# Base class for all background jobs in the application.
#
# Configures global error-handling defaults inherited by every job:
# - Retries transient database deadlocks with polynomial backoff
# - Discards jobs whose serialized records no longer exist
#
# @see https://api.rubyonrails.org/classes/ActiveJob/Exceptions/ClassMethods.html
class ApplicationJob < ActiveJob::Base
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError
end
