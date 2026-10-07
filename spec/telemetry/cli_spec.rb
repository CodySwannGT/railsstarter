# frozen_string_literal: true

require 'json'
require 'open3'
require 'tmpdir'
require 'fileutils'

RSpec.context 'when verifying telemetry through bin/verify-telemetry' do
  let(:script) { File.expand_path('../../bin/verify-telemetry', __dir__) }
  let(:directory) { Dir.mktmpdir('telemetry-cli-') }
  let(:log) { File.join(directory, 'calls.jsonl') }
  let(:environment) do
    { 'PATH' => "#{directory}:#{ENV.fetch('PATH')}", 'TELEMETRY_CALL_LOG' => log,
      'AWS_PROFILE' => 'synthetic-profile', 'AWS_REGION' => 'eu-west-1',
      'OTEL_SERVICE_NAME' => 'renamed-service', 'AWS_ACCESS_KEY_ID' => nil,
      'AWS_SECRET_ACCESS_KEY' => nil, 'AWS_SESSION_TOKEN' => nil }
  end

  around do |example|
    FileUtils.cp(File.join(__dir__, 'fixtures/aws.py'), File.join(directory, 'aws'))
    File.chmod(0o700, File.join(directory, 'aws'))
    example.run
  ensure
    FileUtils.remove_entry(directory)
  end

  def invoke(*, overrides: {})
    Open3.capture3(environment.merge(overrides), 'bash', script, *)
  end

  def calls
    File.exist?(log) ? File.readlines(log).map { |line| JSON.parse(line) } : []
  end

  invalid_values = [nil, '', '   ']
  %w[AWS_PROFILE AWS_REGION OTEL_SERVICE_NAME].each do |setting|
    invalid_values.each do |value|
      it "rejects #{setting}=#{value.inspect} before any AWS call" do
        output, error, status = invoke('health', overrides: { setting => value })
        expect(status.success?).to be(false)
        expect(output + error).to include(setting)
        expect(calls).to be_empty
      end
    end
  end

  { 'health' => '', 'slow' => ' AND responsetime > 1', 'errors' => ' AND fault' }.each do |command, condition|
    it "scopes #{command} summaries to the exact configured service" do
      output, error, status = invoke(command)
      expect(status.success?).to be(true), "#{output}\n#{error}"
      expect(calls.first).to include('--profile', 'synthetic-profile', '--region', 'eu-west-1')
      filter = calls.first.fetch(calls.first.index('--filter-expression') + 1)
      expect(filter).to eq("service(\"renamed-service\")#{condition}")
      expect(output).not_to include('foreign-trace')
    end
  end

  it 'escapes service names inside the X-Ray filter expression' do
    name = 'synthetic"service\\name'
    _output, _error, status = invoke('health', overrides: { 'OTEL_SERVICE_NAME' => name })
    expect(status.success?).to be(true)
    expect(calls.first.last(2)).to eq(%w[--output json])
    filter = calls.first.fetch(calls.first.index('--filter-expression') + 1)
    expect(filter).to eq("service(#{JSON.generate(name)})")
  end

  it 'lets the positional profile override AWS_PROFILE' do
    _output, _error, status = invoke('health', 'positional-profile')
    expect(status.success?).to be(true)
    expect(calls.first).to include('--profile', 'positional-profile')
  end

  it 'shows only the configured service and edges to selected services in the graph' do
    output, error, status = invoke('services')
    expect(status.success?).to be(true), "#{output}\n#{error}"
    expect(output).to include('Services found: 1', 'renamed-service', 'OK=7', '-> 1')
    expect(output).not_to include('foreign-service', '-> 1, 2')
    expect(calls.first).not_to include('--filter-expression')
  end

  it 'consumes trace ID and positional profile separately and scopes displayed segments' do
    output, error, status = invoke('trace', 'synthetic-trace', 'trace-profile')
    expect(status.success?).to be(true), "#{output}\n#{error}"
    expect(calls.first).to include('--trace-ids', 'synthetic-trace', '--profile', 'trace-profile')
    expect(output).to include('Segments in trace: 1', '[renamed-service]')
    expect(output).not_to include('foreign-service')
  end

  it 'uses AWS_PROFILE when trace has no positional profile' do
    _output, _error, status = invoke('trace', 'synthetic-trace')
    expect(status.success?).to be(true)
    expect(calls.first).to include('--profile', 'synthetic-profile')
  end

  it 'does not display foreign-only traces as configured service segments' do
    output, _error, status = invoke('trace', 'synthetic-trace', overrides: { 'TELEMETRY_FOREIGN_TRACE' => '1' })
    expect(status.success?).to be(true)
    expect(output).to include('Segments in trace: 0')
    expect(output).not_to include('[foreign-service]')
  end

  [['trace'], ['unknown'], %w[health profile extra]].each do |arguments|
    it "rejects invalid command grammar #{arguments.inspect} before AWS" do
      _output, _error, status = invoke(*arguments)
      expect(status.success?).to be(false)
      expect(calls).to be_empty
    end
  end

  it 'preserves the AWS read failure exit status' do
    _output, error, status = invoke('health', overrides: { 'TELEMETRY_FAIL' => '1' })
    expect(status.exitstatus).to eq(42)
    expect(error).to include('synthetic X-Ray read failure')
  end
end
