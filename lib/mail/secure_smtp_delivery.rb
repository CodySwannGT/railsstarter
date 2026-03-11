# frozen_string_literal: true

# Ruby Mail library extensions for secure SMTP delivery.
module Mail
  # Secure SMTP delivery method for tenant-specific encrypted email.
  #
  # Inherits standard SMTP behavior with separate credentials
  # configured per environment for emails marked as secure.
  # Registered via +ActionMailer::Base.add_delivery_method+ or
  # selected at runtime by {SecureEmail#apply_secure_delivery}.
  class SecureSmtpDelivery < ::Mail::SMTP
  end
end
