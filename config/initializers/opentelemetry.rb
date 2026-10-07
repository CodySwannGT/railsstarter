# frozen_string_literal: true

if defined?(OpenTelemetry) && ENV['OTEL_EXPORTER_OTLP_ENDPOINT'].present?
  service_name = ENV.fetch('OTEL_SERVICE_NAME', nil)
  raise ArgumentError, 'Set OTEL_SERVICE_NAME when OTEL_EXPORTER_OTLP_ENDPOINT is enabled' if service_name.blank?

  OpenTelemetry::SDK.configure do |c|
    c.service_name = service_name
    c.use_all
  end
end
