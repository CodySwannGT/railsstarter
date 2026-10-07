# frozen_string_literal: true

require 'rails'
require 'active_support/core_ext/object/blank'
require 'opentelemetry/sdk'

RSpec.describe OpenTelemetry::SDK do
  let(:initializer) { File.expand_path('../../../config/initializers/opentelemetry.rb', __dir__) }
  let(:configurator) { OpenTelemetry::SDK::Configurator.new }

  around do |example|
    keys = %w[OTEL_EXPORTER_OTLP_ENDPOINT OTEL_SERVICE_NAME]
    previous = ENV.to_h.slice(*keys)
    keys.each { |key| ENV.delete(key) }
    example.run
  ensure
    keys.each { |key| previous.key?(key) ? ENV[key] = previous[key] : ENV.delete(key) }
  end

  before do
    allow(described_class).to receive(:configure).and_yield(configurator)
    allow(configurator).to receive(:use_all).and_call_original
  end

  [nil, '', '   '].each do |value|
    it "keeps telemetry disabled with endpoint #{value.inspect}" do
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = value if value
      load initializer
      expect(described_class).not_to have_received(:configure)
    end

    it "rejects enabled telemetry with service name #{value.inspect} before SDK configuration" do
      ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://127.0.0.1:4318'
      ENV['OTEL_SERVICE_NAME'] = value if value
      expect { load initializer }.to raise_error(ArgumentError, /OTEL_SERVICE_NAME/)
      expect(described_class).not_to have_received(:configure)
    end
  end

  it 'assigns the exact supplied name to the installed SDK resource without an environment suffix' do
    ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://127.0.0.1:4318'
    ENV['OTEL_SERVICE_NAME'] = 'renamed-service'
    load initializer
    resource = configurator.instance_variable_get(:@resource)
    expect(resource.attribute_enumerator.to_h.fetch('service.name')).to eq('renamed-service')
    expect(configurator).to have_received(:use_all)
  end
end
