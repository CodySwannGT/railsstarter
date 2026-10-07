# frozen_string_literal: true

require 'spec_helper'
require 'mail'
require_relative '../../../lib/mail/secure_smtp_delivery'

RSpec.describe Mail::SecureSmtpDelivery do
  it 'inherits SMTP while retaining separate authored synthetic transport credentials' do
    secure = described_class.new(address: 'secure.smtp.invalid', user_name: 'synthetic-secure-user',
                                 password: 'synthetic-secure-password', enable_starttls_auto: true)
    ordinary = Mail::SMTP.new(address: 'ordinary.smtp.invalid', user_name: 'synthetic-ordinary-user')

    expect(secure).to be_a(Mail::SMTP)
    expect(secure.settings).to include(address: 'secure.smtp.invalid', user_name: 'synthetic-secure-user',
                                       password: 'synthetic-secure-password', enable_starttls_auto: true)
    expect(ordinary.settings).to include(address: 'ordinary.smtp.invalid', user_name: 'synthetic-ordinary-user')
    expect(ordinary.settings[:password]).to be_nil
  end
end
