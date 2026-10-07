# frozen_string_literal: true

require 'open3'
require 'json'
require 'tmpdir'
require 'fileutils'

RSpec.describe Pathname do
  let(:directory) { Dir.mktmpdir('schema-cli-') }
  let(:log) { File.join(directory, 'calls.jsonl') }
  let(:script) { File.expand_path('../../bin/verify-schema', __dir__) }
  let(:environment) do
    { 'PATH' => "#{directory}:#{ENV.fetch('PATH')}", 'SCHEMA_CLI_LOG' => log,
      'AWS_PROFILE' => 'fixture-profile', 'AWS_REGION' => 'us-west-2',
      'ECS_CLUSTER' => 'renamed-cluster', 'ECS_SERVICE' => 'renamed-service',
      'AWS_ACCESS_KEY_ID' => nil, 'AWS_SECRET_ACCESS_KEY' => nil, 'AWS_SESSION_TOKEN' => nil }
  end

  around do |example|
    FileUtils.cp(File.join(__dir__, 'fixtures/aws_cli.rb'), File.join(directory, 'aws'))
    File.chmod(0o700, File.join(directory, 'aws'))
    example.run
  ensure
    FileUtils.remove_entry(directory)
  end

  def invoke(*, **overrides)
    Open3.capture3(environment.merge(overrides), 'bash', script, *)
  end

  def calls
    File.exist?(log) ? File.readlines(log).map { |line| JSON.parse(line) } : []
  end

  invalid_values = [nil, '', '   ']
  %w[AWS_PROFILE AWS_REGION ECS_CLUSTER ECS_SERVICE].each do |setting|
    invalid_values.each do |value|
      it "rejects #{setting}=#{value.inspect} before any AWS call" do
        stdout, stderr, status = invoke(**{ setting => value })
        expect(status.exitstatus).to eq(1)
        expect(stdout + stderr).to include(setting)
        expect(calls).to be_empty
      end
    end
  end

  it 'forwards explicit service, cluster, region and profile to ECS' do
    expect(invoke.last).to be_success
    expect(calls.size).to eq(3)
    expect(calls).to all(include('--profile', 'fixture-profile', '--region', 'us-west-2', '--cluster', 'renamed-cluster'))
    expect(calls.first).to include('--service-name', 'renamed-service')
    expect(calls.last).to include('--command', 'bin/rails db:verify_schema', '--container', 'renamed-app')
  end

  it 'accepts the existing positional profile in preference to AWS_PROFILE' do
    expect(invoke('positional-profile', 'AWS_PROFILE' => nil).last).to be_success
    expect(calls).to all(include('--profile', 'positional-profile'))
  end

  it 'returns failure for a remote schema mismatch' do
    expect(invoke('SCHEMA_RESPONSE' => '{"status":"fail","missing":["renamed_entries"]}').last.exitstatus).to eq(1)
  end

  it 'accepts normally spaced JSON status from the remote task' do
    expect(invoke('SCHEMA_RESPONSE' => '{"status": "pass"}').last).to be_success
  end

  it 'rejects a status fragment that is not a JSON result' do
    expect(invoke('SCHEMA_RESPONSE' => 'not JSON "status":"pass"').last.exitstatus).to eq(1)
  end

  it 'fails when the session has no verification result' do
    expect(invoke('SCHEMA_RESPONSE' => 'session ended').last.exitstatus).to eq(1)
  end

  it 'fails actionably when no task exists' do
    stdout, stderr, status = invoke('SCHEMA_TASK' => 'None')
    expect(status.exitstatus).to eq(1)
    expect(stdout + stderr).to include('No tasks found')
    expect(calls.size).to eq(1)
  end

  it 'fails actionably when no app container exists' do
    stdout, stderr, status = invoke('SCHEMA_CONTAINER' => 'None')
    expect(status.exitstatus).to eq(1)
    expect(stdout + stderr).to include('No suitable containers')
    expect(calls.size).to eq(2)
  end
end
