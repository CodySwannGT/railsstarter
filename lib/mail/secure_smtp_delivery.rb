# frozen_string_literal: true

# Ruby Mail library extensions for secure SMTP delivery.
module Mail
  # Named delivery method inheriting the Mail library's standard SMTP behavior.
  #
  # This subclass does not add encryption, credentials, or message routing.
  # Applications can register it via +ActionMailer::Base.add_delivery_method+
  # and supply their own delivery settings.
  class SecureSmtpDelivery < ::Mail::SMTP
  end
end
