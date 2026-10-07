# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'json'
require 'rbconfig'
require 'timeout'
require 'opentelemetry/exporter/otlp'

RSpec.context 'when exporting actual SDK spans through OTLP' do
  let(:fixture) { File.expand_path('../../../test/runtime/dependency_upgrade/telemetry.rb', __dir__) }

  def export_probe(mode)
    output, error, status = Open3.capture3(RbConfig.ruby, '-rbundler/setup', fixture, mode)
    expect(status.success?).to be(true), "#{output}\n#{error}"
    [JSON.parse(output.lines.last), output + error]
  end

  %w[success gzip].each do |mode|
    it "serializes real SDK spans and flushes/shuts down through synthetic HTTP with #{mode}" do
      result, = export_probe(mode)
      expect(result.fetch('decoded')).to include(
        'service' => 'dependency80-synthetic', 'trace_id' => result.fetch('trace_id'),
        'span_id' => result.fetch('span_id'), 'name' => 'actual-export', 'payload' => 'café 😀'
      )
      request = result.fetch('requests').first
      expect(request.fetch('line')).to eq('POST /v1/traces HTTP/1.1')
      expect(request.dig('headers', 'content-type')).to eq('application/x-protobuf')
      expect(request.dig('headers', 'content-encoding')).to eq(mode == 'gzip' ? 'gzip' : nil)
      expect(result).to include('flush' => 0, 'shutdown' => 0, 'export_statuses' => include(0),
                                'collector_closed' => true, 'collector_joined' => true)
    end
  end

  %w[failure timeout].each do |mode|
    it "reports actual #{mode} export failure with bounded flush and shutdown" do
      result, = export_probe(mode)
      expect(result.fetch('requests')).not_to be_empty
      expect(result.fetch('export_statuses')).to include(1)
      expect(result.fetch('elapsed')).to be < 3
      expect(result.fetch('shutdown')).to eq(0)
      expect(result.values_at('collector_closed', 'collector_joined')).to eq([true, true])
    end
  end

  it 'keeps a disabled initializer from configuring or exporting' do
    result, = export_probe('disabled')
    expect(result.fetch('requests')).to be_empty
    expect(result.fetch('export_statuses')).to be_empty
  end

  it 'rejects a missing service name before configuring an exporter' do
    result, = export_probe('missing')
    expect(result.fetch('error')).to include('OTEL_SERVICE_NAME')
    expect(result.fetch('requests')).to be_empty
  end

  it 'does not count an unsupported protocol warning as an export' do
    result, error = export_probe('unsupported')
    expect(result.fetch('requests')).to be_empty
    expect(error).to match(/unsupported|Unsupported/)
  end
end
