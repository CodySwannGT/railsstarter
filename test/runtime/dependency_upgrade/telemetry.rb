# frozen_string_literal: true

# A synthetic HTTP collector receives the real exporter's serialized protobuf.
# Separate processes isolate SDK use_all instrumentation and global providers.
require 'json'
require 'socket'
require 'zlib'
require 'timeout'
require 'base64'
require 'rails'
require 'active_support/core_ext/object/blank'
require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/all'

# Observe real exporter return values without replacing encoding or transport.
module DependencyExportObservation
  # @return [Array<Integer>] actual exporter outcomes in this isolated process
  def self.statuses
    @statuses ||= []
  end

  # @return [Integer] actual SDK exporter status
  def export(*, **)
    super.tap { |status| DependencyExportObservation.statuses << status }
  end
end

OpenTelemetry::Exporter::OTLP::Exporter.prepend(DependencyExportObservation)
mode = ARGV.fetch(0)
raise 'Unknown telemetry mode' unless %w[success gzip failure timeout disabled missing unsupported].include?(mode)

server = TCPServer.new('127.0.0.1', 0)
requests = []
clients = []
collector = Thread.new do
  loop do
    socket = server.accept
    clients << socket
    request_line = socket.gets
    next unless request_line

    headers = {}
    while (line = socket.gets) && line != "\r\n"
      name, value = line.split(':', 2)
      headers[name.downcase] = value.strip
    end
    bytes = socket.read(Integer(headers.fetch('content-length')))
    requests << { line: request_line.strip, headers: headers, bytes: Base64.strict_encode64(bytes) }
    sleep 0.1 if mode == 'timeout'
    status = mode == 'failure' ? '400 Bad Request' : '200 OK'
    socket.write("HTTP/1.1 #{status}\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
    socket.close
  rescue IOError, Errno::EBADF, Errno::EPIPE
    break
  end
end
ENV.keys.grep(/\AOTEL_/).each { |key| ENV.delete(key) }
ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = "http://127.0.0.1:#{server.addr[1]}"
ENV['OTEL_EXPORTER_OTLP_TIMEOUT'] = '0.03'
ENV['OTEL_BSP_EXPORT_TIMEOUT'] = '0.3'
ENV['OTEL_SERVICE_NAME'] = 'dependency80-synthetic'
ENV['OTEL_EXPORTER_OTLP_COMPRESSION'] = 'gzip' if mode == 'gzip'
ENV['OTEL_EXPORTER_OTLP_PROTOCOL'] = 'unsupported' if mode == 'unsupported'
ENV.delete('OTEL_SERVICE_NAME') if mode == 'missing'
ENV.delete('OTEL_EXPORTER_OTLP_ENDPOINT') if mode == 'disabled'
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
begin
  load File.expand_path('../../../config/initializers/opentelemetry.rb', __dir__)
  provider = OpenTelemetry.tracer_provider
  tracer = provider.tracer('dependency80', '1.0')
  tracer.in_span('actual-export', attributes: { 'synthetic.payload' => 'café 😀' }) do |span|
    @trace_id = span.context.hex_trace_id
    @span_id = span.context.hex_span_id
  end
  flush = provider.force_flush(timeout: mode == 'timeout' ? 0.03 : 1) if provider.respond_to?(:force_flush)
  shutdown = provider.shutdown(timeout: 1) if provider.respond_to?(:shutdown)
rescue ArgumentError => error
  @error = error.message
ensure
  server.close
  clients.each { |socket| socket.close unless socket.closed? }
  collector.join(1)
  collector.kill.join if collector.alive?
end
decoded = requests.filter_map do |request|
  body = Base64.strict_decode64(request.fetch(:bytes))
  body = Zlib.gunzip(body) if request.fetch(:headers)['content-encoding'] == 'gzip'
  payload = Opentelemetry::Proto::Collector::Trace::V1::ExportTraceServiceRequest.decode(body)
  resource = payload.resource_spans.first
  span = resource.scope_spans.flat_map { |scope| scope.spans.to_a }.find { |item| item.name == 'actual-export' }
  next unless span

  { service: resource.resource.attributes.find { |attribute| attribute.key == 'service.name' }&.value&.string_value,
    trace_id: span.trace_id.unpack1('H*'), span_id: span.span_id.unpack1('H*'), name: span.name,
    payload: span.attributes.find { |attribute| attribute.key == 'synthetic.payload' }&.value&.string_value }
end
puts JSON.generate(mode: mode, requests: requests, decoded: decoded, trace_id: @trace_id, span_id: @span_id,
                   flush: flush, shutdown: shutdown, export_statuses: DependencyExportObservation.statuses, error: @error,
                   elapsed: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
                   collector_joined: !collector.alive?, collector_closed: server.closed?)
