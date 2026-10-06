# frozen_string_literal: true

require 'json'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'yaml'

# rubocop:disable-next RSpec/DescribeClass -- Execute the Git and shell release contract without Rails/database boot.
RSpec.describe 'Released artifact contract' do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:helper) { File.join(root, 'bin/resolve-release-artifact') }
  let(:workflow) { YAML.load_file(File.join(root, 'templates/github/workflows/deploy-ecs.yml')) }
  let(:steps) { workflow.fetch('jobs').fetch('deploy_rails').fetch('steps') }
  let(:directory) { Dir.mktmpdir('released-artifact-') }
  let(:image_id) { "sha256:#{'a' * 64}" }
  let(:repository) { '123.dkr.ecr.us-east-1.amazonaws.com/web' }
  let(:sha) { 'e' * 40 }

  around do |example|
    git('init', '--quiet')
    git('config', 'user.email', 'synthetic@example.invalid')
    git('config', 'user.name', 'Synthetic release fixture')
    example.run
  ensure
    FileUtils.remove_entry(directory)
  end

  def git(*)
    output, error, status = Open3.capture3('git', *, chdir: directory)
    raise error unless status.success?

    output.strip
  end

  def commit(message, version = '1.0.0')
    File.write(File.join(directory, 'VERSION'), "#{version}\n")
    File.write(File.join(directory, 'change'), message)
    git('add', '.')
    git('commit', '--quiet', '-m', message)
    git('rev-parse', 'HEAD')
  end

  def release(version = '1.1.0', tag: "v#{version}-staging.1", annotated: true)
    released = commit("chore(release): #{version}", version)
    annotated ? git('tag', '-a', tag, '-m', "chore(release): #{tag}") : git('tag', tag)
    released
  end

  def resolve(trigger, tip = git('rev-parse', 'HEAD'), branch = 'staging')
    Open3.capture3('bash', helper, 'source', trigger, branch, tip, chdir: directory)
  end

  def script(name)
    steps.find { |step| step['name'] == name }.fetch('run')
  end

  def shell(code, environment = {})
    Open3.capture3(environment, 'bash', '-e', '-o', 'pipefail', '-c', code, chdir: directory)
  end

  def image(overrides = {})
    fixture = File.read(File.join(root, 'spec/deployment/fixtures/deployment_cli.py'))
    File.write(File.join(directory, 'docker'), fixture)
    File.chmod(0o700, File.join(directory, 'docker'))
    env = { 'PATH' => "#{directory}:#{ENV.fetch('PATH')}", 'CLI_LOG' => File.join(directory, 'calls.jsonl'),
            'FIXTURE_IMAGE_ID' => image_id, 'FIXTURE_DIGEST' => "#{repository}@sha256:#{'b' * 64}",
            'FIXTURE_REVISION' => sha }.merge(overrides)
    Open3.capture3(env, 'bash', helper, 'image', image_id, repository, sha)
  end

  it 'concurrent-release/self-push keeps the original eligible and detects cancelling policy' do
    eligible = ->(policy, message) { !policy && !message.start_with?('chore(release):') }
    policy = workflow.fetch('concurrency').fetch('cancel-in-progress')
    expect(eligible.call(policy, 'feat: trigger')).to be(true)
    expect(eligible.call(policy, 'chore(release): 1.1.0')).to be(false)
    expect(eligible.call(true, 'feat: trigger')).to be(false)
    condition = workflow.fetch('jobs').fetch('deploy_rails').fetch('if')
    expect(condition).to include('!cancelled()', "!startsWith(github.event.head_commit.message, 'chore(release):')")
  end

  it 'failed-release/visible-outcome executes the actual guard and falsifies wrong outcomes' do
    %w[success failure skipped cancelled].each do |outcome|
      output, error, status = shell(script('Require successful release'), { 'RELEASE_RESULT' => outcome })
      expect(status.success?).to eq(outcome == 'success')
      expect(output + error).to include('deployment refused') unless outcome == 'success'
    end
  end

  it 'branch-advancement/exact-source selects the tagged release instead of trigger or advanced HEAD' do
    trigger = commit('feat: trigger')
    released = release
    advanced = commit('fix: later ordinary work')
    output, error, status = resolve(trigger)
    expect(status.success?).to be(true), error
    expect(output).to eq("RELEASE_SHA=#{released}\nRELEASE_TAG=v1.1.0-staging.1\n")
    git('checkout', '--quiet', '--detach', released)
    env = { 'RELEASE_SHA' => released, 'RELEASE_TAG' => 'v1.1.0-staging.1' }
    expect(shell(script('Verify released checkout'), env).last.success?).to be(true)
    git('checkout', '--quiet', '--detach', advanced)
    output, error, status = shell(script('Verify released checkout'), env)
    expect(status.success?).to be(false)
    expect(output + error).to include('Released checkout mismatch')
  end

  it 'replay/artifact-identity is stable after ordinary advancement and rejects another released artifact' do
    trigger = commit('feat: trigger')
    release
    first = resolve(trigger)
    commit('fix: later ordinary work')
    replay = resolve(trigger)
    expect(first.first).to eq(replay.first)
    expect([first.last.success?, replay.last.success?]).to eq([true, true])
    release('1.2.0', tag: 'v1.2.0-staging.2')
    _output, error, status = resolve(trigger)
    expect(status.success?).to be(false)
    expect(error).to include('ambiguous release, replay rejected')
  end

  it 'rejects missing or lightweight release artifacts rather than building the branch' do
    trigger = commit('feat: trigger')
    expect(resolve(trigger).last.success?).to be(false)
    release(annotated: false)
    _output, error, status = resolve(trigger)
    expect(status.success?).to be(false)
    expect(error).to include('found 0')
  end

  it 'rejects wrong environment tags and release commits not directly bound to the trigger' do
    trigger = commit('feat: trigger')
    commit('fix: intermediate work')
    release(tag: 'v1.1.0-foreign.1')
    expect(resolve(trigger).last.success?).to be(false)
    git('tag', '-a', 'v1.1.0-staging.1', '-m', 'synthetic')
    _output, error, status = resolve(trigger)
    expect(status.success?).to be(false)
    expect(error).to include('not the direct successor')
  end

  it 'rejects duplicate valid tags, wrong release subjects and wrong versions' do
    trigger = commit('feat: trigger')
    release
    git('tag', '-a', 'v1.1.0-staging.2', '-m', 'synthetic')
    expect(resolve(trigger).last.success?).to be(false)
    git('tag', '-d', 'v1.1.0-staging.1', 'v1.1.0-staging.2')
    git('tag', '-a', 'v9.9.9-staging.1', '-m', 'synthetic')
    expect(resolve(trigger).last.success?).to be(false)
    wrong = commit('fix: not a release', '2.0.0')
    git('tag', '-a', 'v2.0.0-staging.1', '-m', 'synthetic')
    expect(resolve(trigger, wrong).last.success?).to be(false)
  end

  it 'rejects unavailable, abbreviated and unrelated source commits' do
    trigger = commit('feat: trigger')
    release
    expect(resolve(trigger, '0' * 40).last.success?).to be(false)
    expect(resolve(trigger[0, 7]).last.success?).to be(false)
    git('checkout', '--quiet', '--orphan', 'unrelated')
    unrelated = commit('unrelated history')
    _output, error, status = resolve(trigger, unrelated)
    expect(status.success?).to be(false)
    expect(error).to include('unrelated to trigger')
  end

  it 'supports the actual production annotated tag namespace' do
    trigger = commit('feat: trigger')
    released = release(tag: 'v1.1.0')
    output, error, status = resolve(trigger, released, 'main')
    expect(status.success?).to be(true), error
    expect(output).to include("RELEASE_SHA=#{released}", 'RELEASE_TAG=v1.1.0')
  end

  it 'executes exact-image/revision-and-digest selection against explicit synthetic CLI protocol' do
    output, error, status = image
    expect(status.success?).to be(true), error
    expect(output.strip).to eq("#{repository}@sha256:#{'b' * 64}")
  end

  {
    'wrong-revision' => { 'FIXTURE_REVISION' => 'f' * 40 },
    'missing-revision' => { 'FIXTURE_REVISION' => '' },
    'wrong-digest-image' => { 'FIXTURE_WRONG_DIGEST_IMAGE' => '1' },
    'wrong-repository' => { 'FIXTURE_WRONG_REPOSITORY' => '1' },
    'malformed-digest' => { 'FIXTURE_MALFORMED_DIGEST' => '1' },
    'missing-digest' => { 'FIXTURE_NO_DIGEST' => '1' },
    'ambiguous-digest' => { 'FIXTURE_AMBIGUOUS_DIGEST' => '1' }
  }.each do |name, overrides|
    it "rejects exact-image/#{name} through the actual executable detector" do
      _output, error, status = image(overrides)
      expect(status.success?).to be(false)
      expect(error).to include('::error::')
    end
  end

  def install_commands
    fixture = File.read(File.join(root, 'spec/deployment/fixtures/deployment_cli.py'))
    %w[aws docker].each do |name|
      File.write(File.join(directory, name), fixture)
      File.chmod(0o700, File.join(directory, name))
    end
  end

  def prepare_pipeline(released)
    FileUtils.mkdir_p(File.join(directory, 'bin'))
    %w[resolve-release-artifact publish-assets].each do |name|
      FileUtils.cp(File.join(root, 'bin', name), File.join(directory, 'bin', name))
    end
    install_commands
    File.write(File.join(directory, 'github-env'), '')
    { 'PATH' => "#{directory}:#{ENV.fetch('PATH')}", 'CLI_LOG' => File.join(directory, 'calls.jsonl'),
      'FIXTURE_IMAGE_ID' => image_id, 'FIXTURE_DIGEST' => "#{repository}@sha256:#{'b' * 64}",
      'FIXTURE_REVISION' => released, 'RELEASE_SHA' => released, 'RELEASE_TAG' => 'v1.1.0-staging.1',
      'IMAGE_TAG' => released, 'ECR_REGISTRY' => '123.dkr.ecr.us-east-1.amazonaws.com',
      'APP_STAGE' => 'staging', 'RAILS_ECR_REPO' => 'web', 'WORKER_ECR_REPO' => 'worker',
      'RAILS_TASK_FAMILY' => 'web-task', 'WORKER_TASK_FAMILY' => 'worker-task',
      'S3_BUCKET_NAME' => 'synthetic-bucket', 'AWS_REGION' => 'us-east-1',
      'GITHUB_ENV' => File.join(directory, 'github-env'), 'TMPDIR' => directory,
      'AWS_ACCESS_KEY_ID' => nil, 'AWS_SECRET_ACCESS_KEY' => nil, 'AWS_SESSION_TOKEN' => nil }
  end

  def pipeline(environment)
    names = ['Verify released checkout', 'Build and push Rails image', 'Build and push Worker image',
             'Publish assets from the exact pushed web image', 'Register new ECS task definitions']
    code = names.map do |name|
      script(name).gsub(/\$\{\{ env\.(\w+) \}\}/) { "$#{Regexp.last_match(1)}" }
                  .gsub('/tmp/task-def.json', File.join(directory, 'task-def.json'))
    end.join("\nset -a; source \"$GITHUB_ENV\"; set +a\n")
    shell(code, environment)
  end

  it 'runs the actual fetch/resolver step against a local Git remote and preserves selected outputs' do
    trigger = commit('feat: trigger')
    released = release
    commit('fix: later ordinary work')
    git('branch', 'staging')
    git('remote', 'add', 'origin', directory)
    env = prepare_pipeline(released).merge({
      'TRIGGER_SHA' => trigger, 'RELEASE_BRANCH' => 'staging',
      'RUNNER_TEMP' => directory, 'GITHUB_OUTPUT' => File.join(directory, 'outputs')
    })
    output, error, status = shell(script('Resolve released artifact'), env)
    expect(status.success?).to be(true), output + error
    expect(File.read(env.fetch('GITHUB_OUTPUT'))).to eq("sha=#{released}\ntag=v1.1.0-staging.1\n")
  end

  it 'executes actual template build/extraction/digest-pinned ECS metadata with the exact selected source' do
    trigger = commit('feat: trigger')
    released = release
    commit('fix: branch advancement')
    selected, error, status = resolve(trigger)
    expect(status.success?).to be(true), error
    expect(selected).to include("RELEASE_SHA=#{released}")
    git('checkout', '--quiet', '--detach', released)
    output, error, status = pipeline(prepare_pipeline(released))
    expect(status.success?).to be(true), output + error
    calls = pipeline_calls
    expect_built_source(calls, released)
    expect_release_registration(calls, released)
  end

  def pipeline_calls
    File.readlines(File.join(directory, 'calls.jsonl')).map { |line| JSON.parse(line) }
  end

  def select_calls(calls, tool, prefix)
    calls.select { |call| call['tool'] == tool && call['args'].first(prefix.length) == prefix }
  end

  def expect_built_source(calls, released)
    builds = select_calls(calls, 'docker', ['build'])
    expect(builds.map { |call| call.fetch('source_sha') }).to eq([released, released])
    expect(builds.map { |call| call['args'].join(' ') }).to all(include("org.opencontainers.image.revision=#{released}", ":#{released}"))
    extraction = select_calls(calls, 'docker', ['create']).first
    expect(extraction.fetch('args')).to include(image_id)
  end

  def expect_release_registration(calls, released)
    registrations = select_calls(calls, 'aws', %w[ecs register-task-definition])
    expect(registrations.length).to eq(2)
    expect(registrations.map { |call| call.fetch('args') }).to all(include("key=release-sha,value=#{released}", 'key=release-tag,value=v1.1.0-staging.1'))
    expect_registered_images(registrations)
    expect(calls.index(select_calls(calls, 'aws', %w[s3 sync]).first)).to be < calls.index(registrations.first)
  end

  def expect_registered_images(registrations)
    expected = ["#{repository}@sha256:#{'b' * 64}", "#{repository.sub('/web', '/worker')}@sha256:#{'b' * 64}"]
    expect(registrations.map { |call| call['task']['containerDefinitions'].first['image'] }).to eq(expected)
  end

  { 'wrong-revision' => { 'FIXTURE_REVISION' => 'f' * 40 },
    'wrong-digest-image' => { 'FIXTURE_WRONG_DIGEST_IMAGE' => '1' } }.each do |name, overrides|
    it "rejects actual template publication on #{name} before extraction or ECS calls" do
      commit('feat: trigger')
      released = release
      _output, error, status = pipeline(prepare_pipeline(released).merge(overrides))
      expect(status.success?).to be(false)
      expect(error).to include('::error::')
      expect(pipeline_calls.select { |call| call['tool'] == 'aws' || call['args'].first == 'create' }).to be_empty
    end
  end

  it 'pins bootstrap/source/image wiring and exposes a mutated trigger-image selection' do
    bootstrap = steps.find { |step| step['name'] == 'Checkout trigger' }
    exact = steps.find { |step| step['name'] == 'Checkout exact released source' }
    expect(bootstrap.fetch('with').fetch('ref')).to eq('${{ github.sha }}')
    expect(exact.fetch('with').fetch('ref')).to eq('${{ steps.released.outputs.sha }}')
    builds = steps.select { |step| step.fetch('run', '').include?('docker build') }
    identities = builds.map { |step| step.fetch('env').fetch('IMAGE_TAG') }
    expect(identities).to eq(['${{ env.RELEASE_SHA }}'] * 2)
    expect(identities.map { '${{ github.sha }}' }).not_to eq(identities)
    expect(builds.map { |step| step.fetch('run') }).to all(include('--label org.opencontainers.image.revision="$RELEASE_SHA"'))
  end
end
