# frozen_string_literal: true

require 'json'
require 'open3'
require 'yaml'

# This checks the authored required caller, before actual hosted execution proof.
RSpec.describe 'Required recurring worker caller' do # rubocop:disable RSpec/DescribeClass -- required workflow is a cross-language contract
  let(:root) { File.expand_path('../..', __dir__) }
  let(:path) { File.join(root, '.github/workflows/recurring-worker-runtime.yml') }
  let(:workflow) { YAML.safe_load_file(path) }
  let(:job) { workflow.fetch('jobs').fetch('recurring-worker-runtime') }
  let(:steps) { job.fetch('steps') }

  it 'runs for every pull request without optional job or command conditions' do
    events = workflow.fetch('on', workflow[true])
    expect(events).to eq('pull_request' => nil, 'workflow_dispatch' => nil)
    expect(job.keys & %w[if continue-on-error]).to be_empty
    commands = steps.select { |step| step.fetch('run', '').strip == 'bin/test-recurring-worker' }
    expect(commands.size).to eq(1)
    expect(commands.first.keys & %w[if continue-on-error env working-directory]).to be_empty
    expect(workflow.keys & %w[env secrets]).to be_empty
  end

  it 'always retains all exported evidence and fails when none was produced' do
    collector = steps.find { |step| step.fetch('uses', '').start_with?('actions/upload-artifact@') }
    expect(collector.fetch('if')).to eq('always()')
    expect(collector.fetch('with')).to include('path' => 'tmp/recurring-worker-results/*.json', 'if-no-files-found' => 'error')
    expect(collector).not_to have_key('continue-on-error')
  end

  it 'sets up current project Ruby and lockfile Bundler without another version declaration' do
    setup = steps.find { |step| step.fetch('uses', '').start_with?('ruby/setup-ruby@') }
    expect(setup.fetch('with')).to eq('bundler-cache' => true)
    expect(File.read(File.join(root, '.ruby-version')).strip).to eq(RUBY_VERSION)
    expect(File.read(File.join(root, 'test/runtime/recurring_worker/runner.py'))).to include("(ROOT / '.ruby-version').read_text().strip()")
    expect(steps.any? { |step| step.fetch('uses', '').start_with?('actions/setup-python@') }).to be(true)
  end

  it 'provides native MySQL headers before Bundler builds mysql2' do
    headers = steps.find { |step| step.fetch('name', '') == 'Install MySQL native build headers' }
    setup = steps.find { |step| step.fetch('uses', '').start_with?('ruby/setup-ruby@') }
    expect(headers.fetch('run')).to include('libmysqlclient-dev', 'mysql_config --version')
    expect(steps.index(headers)).to be < steps.index(setup)
  end

  it 'provides the tested MySQL image before invoking the real owned-runtime executable' do
    expected = 'mysql:8.4.11@sha256:6ea90827b1100f8f2ae306a539f86d2c264a26ed435a2a9f75551dd5c3aeb242'
    provision = steps.find { |step| step.fetch('name', '') == 'Prepare tested MySQL and local Docker' }
    expect(provision.fetch('run')).to include("docker pull #{expected}", "docker tag #{expected} mysql:8.4", 'docker info')
    invocation = steps.index { |step| step.fetch('run', '').strip == 'bin/test-recurring-worker' }
    expect(steps.index(provision)).to be < invocation
    expect(File.executable?(File.join(root, 'bin/test-recurring-worker'))).to be(true)
  end

  it 'enforces immutable action revisions with the official checker' do
    checker = File.join(root, 'scripts/check-third-party-action-pins.mjs')
    script = <<~JS
      import {readFileSync} from 'node:fs';
      import {pathToFileURL} from 'node:url';
      const gate = await import(pathToFileURL(process.argv[2]));
      const refs = gate.findActionRefs(readFileSync(process.argv[3], 'utf8'));
      console.log(JSON.stringify({count:refs.length, failures:refs.filter(ref=>gate.evaluateReference(ref)!=='ok')}));
    JS
    output, error, status = Open3.capture3('node', '--input-type=module', '-e', script, 'recurring-caller-policy', checker, path)
    expect(status.success?).to be(true), error
    expect(JSON.parse(output)).to eq('count' => 4, 'failures' => [])
  end
end
