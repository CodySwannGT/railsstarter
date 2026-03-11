# frozen_string_literal: true

if defined?(OpenTelemetry) && ENV['OTEL_EXPORTER_OTLP_ENDPOINT'].present?
  OpenTelemetry::SDK.configure do |c|
    c.service_name = "#{ENV.fetch('OTEL_SERVICE_NAME', 'railsstarter')}-#{Rails.env}"
    c.use_all
  end
end
