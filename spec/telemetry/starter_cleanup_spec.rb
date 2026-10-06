# frozen_string_literal: true

require 'erb'
require 'yaml'
require 'json'
require 'mail'

RSpec.context 'with reusable starter configuration' do
  let(:root) { File.expand_path('../..', __dir__) }

  it 'lets the reusable worker process arbitrary consumer and recurring queues' do
    source = File.read(File.join(root, 'config/queue.yml'))
    queues = YAML.safe_load(ERB.new(source).result, aliases: true)
    %w[development test staging production].each do |environment|
      expect(queues.fetch(environment).fetch('workers').first.fetch('queues')).to eq('*')
    end
  end

  it 'has no Brakeman suppression for source files that do not exist' do
    warnings = JSON.parse(File.read(File.join(root, 'config/brakeman.ignore'))).fetch('ignored_warnings')
    absent = warnings.reject { |warning| File.file?(File.join(root, warning.fetch('file'))) }
    expect(absent).to be_empty
  end

  it 'preserves the SMTP subclass and standard delivery behavior' do
    load File.join(root, 'lib/mail/secure_smtp_delivery.rb')
    delivery = Mail::SecureSmtpDelivery.new({})
    standard = Mail::SMTP.new({})
    expect(delivery.settings).to eq(standard.settings)
    expect(delivery.method(:deliver!).owner).to eq(Mail::SMTP)
  end
end
