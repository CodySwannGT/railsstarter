# frozen_string_literal: true

require 'digest'
require 'json'
require 'open3'
require 'tmpdir'
require 'yaml'

# rubocop:disable-next RSpec/DescribeClass -- This contract spans the starter workflow inventory.
RSpec.describe 'Starter CI migration' do
  let(:root) { File.expand_path('../..', __dir__) }
  # #74 reviewed release/source/artifact contract, built on carrier d8e2d726.
  # Only uses refs/trailing comments are removed for the frozen byte detector.
  let(:reviewed_template_sha256) { '52c2354e8d249ed58167ab158fcdf0a49ff4e692934861bc441e0228b7e17b38' }
  # Same reviewed commit, image workflow blobf8bd75b5cb081911472fec4f3445355573e2f221.
  let(:reviewed_image_workflow_sha256) { 'd937643072fa5b9709c38668282099ae2c06631e12ae97afe4f29d6b3a8c2395' }
  let(:runtime_image_probe_step) do
    <<~YAML.lines.map { |line| "      #{line}" }.join
      - name: Boot both immutable production images with authored SDK responses
        run: |
          python3 bin/verify-runtime-images.py \\
            --web-image deployment-proof-web --worker-image deployment-proof-worker \\
            --report-directory "$RUNNER_TEMP/deployment-image-evidence"
    YAML
  end
  let(:template_path) { 'templates/github/workflows/deploy-ecs.yml' }
  let(:retired_callers) do
    %w[claude-code-review-response claude-nightly-code-complexity claude-nightly-test-coverage
       claude-nightly-test-improvement claude-sync-down-branches]
  end

  def workflow_inventory(directory)
    Dir.glob(File.join(directory, '*.{yml,yaml}')).to_h do |path|
      [File.basename(path), YAML.load_file(path)]
    end
  end

  def deployment_routes(inventory)
    inventory.select do |_path, workflow|
      workflow.fetch('jobs').values.any? do |job|
        job.fetch('uses', '').include?('/release-rails.yml@') || job.fetch('steps', []).any? do |step|
          step.fetch('run', '').match?(%r{aws\s+ecs\s+(register-task-definition|run-task|update-service)|bin/deploy})
        end
      end
    end.keys
  end

  def action_checker_path(project_root = root)
    candidates = ['scripts/check-third-party-action-pins.mjs',
                  'node_modules/@codyswann/lisa/scripts/check-third-party-action-pins.mjs']
    path = candidates.map { |candidate| File.join(project_root, candidate) }.find { |candidate| File.file?(candidate) }
    path || raise('Official action-pin checker missing: adopt its tracked script/import closure before CI')
  end

  def action_report(content)
    # Tracked common-adoption source takes precedence. Installed official source
    # is a local pre-adoption fallback; missing both is an explicit failure.
    # A nonblocking pipe can be temporarily empty; wait for EOF before checking.
    checker = action_checker_path
    script = <<~JS
      import {pathToFileURL} from 'node:url';
      const gate = await import(pathToFileURL(process.argv[2]));
      process.stdin.setEncoding('utf8');
      let content = '';
      for await (const chunk of process.stdin) content += chunk;
      const refs = gate.findActionRefs(content);
      console.log(JSON.stringify({checked: refs.length, refs: refs, findings: refs
        .filter(ref => gate.evaluateReference(ref) !== 'ok')
        .map(ref => ({action: ref.action, ref: ref.ref, verdict: gate.evaluateReference(ref)}))}));
    JS
    output, error, status = Open3.capture3('node', '--input-type=module', '-e', script, 'ci-migration-policy-probe', checker, stdin_data: content)
    expect(status.success?).to be(true), error
    JSON.parse(output)
  end

  def without_action_pins(content)
    content.lines.map do |line|
      match = line.match(/^(\s*(?:-\s*)?uses:\s*)([^\s#]+)/)
      match ? "#{match[1]}#{match[2].split('@').first}\n" : line
    end.join
  end

  it 'retires all five obsolete caller files without replacing their autonomous schedules' do
    inventory = workflow_inventory(File.join(root, '.github/workflows'))
    expect(inventory.keys & retired_callers.map { |name| "#{name}.yml" }).to be_empty
    scheduled = inventory.select { |_path, workflow| (workflow['on'] || workflow[true] || {}).key?('schedule') }
    expect(scheduled.keys).to be_empty
  end

  it 'has no executable default deployment, including renamed alternate routes' do
    inventory = workflow_inventory(File.join(root, '.github/workflows'))
    expect(inventory).not_to have_key('deploy.yml')
    expect(deployment_routes(inventory)).to be_empty
  end

  it 'detects an alternate executable deployment route in an actual temporary YAML file' do
    Dir.mktmpdir('ci-migration-route-') do |directory|
      File.write(File.join(directory, 'renamed.yml'), <<~YAML)
        on: {workflow_dispatch: {}}
        jobs:
          alternate:
            steps:
              - run: aws ecs update-service --cluster synthetic --service synthetic
      YAML
      expect(deployment_routes(workflow_inventory(directory))).to eq(['renamed.yml'])
    end
  end

  it 'preserves every reviewed #74 template byte except immutable action refs and their comments' do
    content = File.binread(File.join(root, template_path))
    expect(Digest::SHA256.hexdigest(without_action_pins(content).b)).to eq(reviewed_template_sha256)
  end

  it 'retains every reviewed image-verification byte alongside the actual runtime probe' do
    path = '.github/workflows/verify-deployment-images.yml'
    content = File.binread(File.join(root, path))
    expect(content.scan(runtime_image_probe_step).length).to eq(1)
    expect(Digest::SHA256.hexdigest(content.sub(runtime_image_probe_step, ''))).to eq(reviewed_image_workflow_sha256)
  end

  it 'verifies frozen evidence with absent historical objects and fails explicitly without either official checker' do
    Dir.mktmpdir('ci-migration-shallow-') do |directory|
      _output, error, status = Open3.capture3('git', 'init', '--quiet', directory)
      expect(status.success?).to be(true), error
      File.write(File.join(directory, '.git/shallow'), "35acfcfd6ee6cd8ff27b1605a38cf59ed12656d1\n")
      shallow, _error, status = Open3.capture3('git', 'rev-parse', '--is-shallow-repository', chdir: directory)
      expect([status.success?, shallow.strip]).to eq([true, 'true'])
      _output, _error, status = Open3.capture3('git', 'show', '35acfcfd6ee6cd8ff27b1605a38cf59ed12656d1', chdir: directory)
      expect(status.success?).to be(false)
      path = File.join(directory, 'deploy-ecs.yml')
      File.binwrite(path, File.binread(File.join(root, template_path)))
      expect(Digest::SHA256.hexdigest(without_action_pins(File.binread(path)).b)).to eq(reviewed_template_sha256)
      expect { action_checker_path(directory) }.to raise_error(RuntimeError, /Official action-pin checker missing/)
    end
  end

  it 'parses and enforces immutable pins on the dormant template through the official gate' do
    content = File.read(File.join(root, template_path))
    expect(YAML.safe_load(content).fetch('jobs').keys).to include('release', 'deploy_rails')
    report = action_report(content)
    expect(report.fetch('checked')).to be > 0
    expect(report.fetch('findings')).to be_empty
    expect(report.fetch('refs').map { |ref| ref.fetch('ref') }).to all(match(/\A[0-9a-f]{40}\z/))
  end

  it 'reaches quoted mutable actions in a mutated dormant-template fixture' do
    content = File.read(File.join(root, template_path))
    mutation = content.sub(%r{uses: aws-actions/amazon-ecr-login@[0-9a-f]{40}},
                           'uses: "synthetic-vendor/action@moving"')
    expect(mutation).not_to eq(content)
    Dir.mktmpdir('ci-migration-pin-') do |directory|
      path = File.join(directory, 'deploy-ecs.yml')
      File.write(path, mutation)
      report = action_report(File.read(path))
      finding = { 'action' => 'synthetic-vendor/action', 'ref' => 'moving', 'verdict' => 'mutable-ref' }
      expect(report.fetch('findings')).to eq([finding])
    end
  end
end
