# frozen_string_literal: true

# Exercise the executable deployment boundaries without contacting AWS or starting
# containers. The fixtures deliberately implement the CLI protocol used by these
# entry points; full image construction is verified separately with Docker.
require 'json'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'timeout'

# rubocop:disable-next RSpec/DescribeClass -- The public interface is a shell command.
RSpec.describe 'Asset publication' do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:image_id) { "sha256:#{'a' * 64}" }
  let(:digest) { "123.dkr.ecr.us-east-1.amazonaws.com/web@sha256:#{'b' * 64}" }
  let(:directory) { Dir.mktmpdir('asset-publication-spec-') }
  let(:log) { File.join(directory, 'calls.jsonl') }
  let(:environment) do
    {
      'PATH' => "#{directory}:#{ENV.fetch('PATH')}", 'CLI_LOG' => log,
      'FIXTURE_IMAGE_ID' => image_id, 'FIXTURE_DIGEST' => digest,
      'TMPDIR' => directory, 'AWS_ACCESS_KEY_ID' => nil,
      'AWS_SECRET_ACCESS_KEY' => nil, 'AWS_SESSION_TOKEN' => nil
    }
  end

  around do |example|
    fixture = File.read(File.join(__dir__, 'fixtures', 'deployment_cli.py'))
    %w[aws docker].each do |command|
      File.write(File.join(directory, command), fixture)
      File.chmod(0o700, File.join(directory, command))
    end
    example.run
  ensure
    FileUtils.remove_entry(directory)
  end

  def invoke(script, *, overrides: {})
    source = script == 'deploy-staging' ? deployment_source : root
    inputs = environment
    inputs = inputs.merge('FIXTURE_REVISION' => source_revision, 'FIXTURE_SOURCE_ROOT' => deployment_source) if script == 'deploy-staging'
    Open3.capture3(inputs.merge(overrides), 'bash', File.join(source, 'bin', script), *, chdir: source)
  end

  # The executable deploy helper belongs to a real, clean disposable repository.
  # CLI protocol scripts remain outside that source tree, as credentials would.
  def deployment_source
    @deployment_source ||= begin
      source = File.join(directory, 'consumer')
      FileUtils.mkdir_p(File.join(source, 'bin'))
      %w[deploy-staging publish-assets resolve-release-artifact].each do |script|
        FileUtils.cp(File.join(root, 'bin', script), File.join(source, 'bin', script))
      end
      %w[Dockerfile worker.Dockerfile].each { |file| File.write(File.join(source, file), "FROM scratch\n") }
      File.write(File.join(source, 'VERSION'), "1.0.0\n")
      File.write(File.join(source, '.gitignore'), "private-input\n")
      git_source(source, 'init', '-q')
      git_source(source, 'add', '.')
      git_source(source, '-c', 'user.name=Deployment fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'Fixture source')
      source
    end
  end

  def git_source(source, *)
    output, error, status = Open3.capture3('git', '-C', source, *)
    raise "Fixture Git failed: #{output}\n#{error}" unless status.success?

    output.strip
  end

  def source_revision
    git_source(deployment_source, 'rev-parse', 'HEAD')
  end

  def calls
    File.exist?(log) ? File.readlines(log).map { |line| JSON.parse(line) } : []
  end

  def aws_calls(service, operation)
    calls.select { |call| call['tool'] == 'aws' && call['args'][0, 2] == [service, operation] }
  end

  def expect_clean_extraction
    expect(calls.any? { |call| call['tool'] == 'docker' && call['args'][0, 2] == %w[rm -f] }).to be(true)
    expect(Dir.glob(File.join(directory, 'rails-assets.*'))).to be_empty
    expect(Dir.glob(File.join(directory, 'rails-deploy-source.*'))).to be_empty
  end

  def workflow_steps
    YAML.load_file(File.join(root, 'templates', 'github', 'workflows', 'deploy-ecs.yml'))
        .fetch('jobs').fetch('deploy_rails').fetch('steps')
  end

  def invoke_ci_publication(overrides: {})
    job_environment = environment.merge({
      'WEB_IMAGE_ID' => image_id, 'WORKER_IMAGE_ID' => "sha256:#{'c' * 64}",
      'ECR_REGISTRY' => '123.dkr.ecr.us-east-1.amazonaws.com',
      'RAILS_ECR_REPO' => 'web', 'WORKER_ECR_REPO' => 'worker',
      'RAILS_TASK_FAMILY' => 'web-task', 'WORKER_TASK_FAMILY' => 'worker-task',
      'CLUSTER_NAME' => 'fixture-cluster', 'RAILS_SERVICE_NAME' => 'web-service',
      'WORKER_SERVICE_NAME' => 'worker-service', 'RAILS_CONTAINER_NAME' => 'AppContainer',
      'PRIVATE_SUBNETS' => 'subnet-fixture', 'ECS_SECURITY_GROUP' => 'sg-fixture',
      'S3_BUCKET_NAME' => 'asset-bucket', 'AWS_REGION' => 'us-east-1', 'RELEASE_SHA' => 'e' * 40, 'RELEASE_TAG' => 'v1.0.0-staging.1', 'FIXTURE_REVISION' => 'e' * 40,
      'GITHUB_ENV' => File.join(directory, 'github-env')
    }).merge(overrides)
    selected = workflow_steps.select do |step|
      step.fetch('run', '').match?(%r{bin/publish-assets|aws ecs (register-task-definition|run-task|update-service)})
    end
    script = selected.map do |step|
      step.fetch('run')
          .gsub(/\$\{\{ env\.(\w+) \}\}/) { "$#{Regexp.last_match(1)}" }
          .gsub('/tmp/task-def.json', File.join(directory, 'task-def.json'))
    end.join("\nset -a; source \"$GITHUB_ENV\"; set +a\n")
    Open3.capture3(job_environment, 'bash', '-e', '-o', 'pipefail', '-c', script, chdir: root)
  end

  def expect_credential_free_builds
    expect(aws_calls('configure', 'export-credentials')).to be_empty
    builds = calls.select { |call| call['tool'] == 'docker' && call['args'].first == 'build' }
    expect(builds.flat_map { |call| call['args'] }.join(' ')).not_to match(/--secret|S3_BUCKET_NAME|aws_credentials/)
  end

  def expect_web_image_identity
    create = calls.find { |call| call['tool'] == 'docker' && call['args'].first == 'create' }
    expect(create['args']).to include(image_id)
    registration = aws_calls('ecs', 'register-task-definition').first
    expect(registration['task']['containerDefinitions'].first['image']).to eq(digest)
  end

  def expect_committed_builds(builds, revision)
    builds.each do |build|
      expect(build['args']).to include("org.opencontainers.image.revision=#{revision}")
      expect(build['context_version']).to eq("1.0.0\n")
      expect(build['context_private']).to be(false)
      expect(build['context_git']).to be(false)
      expect(File).not_to exist(build['args'].last)
    end
  end

  it 'consumes the complete ECR password pipe before Docker login exits' do
    # Exceed pipe capacity so a consumer that closes stdin fails regardless of scheduling.
    script = <<~SH
      python3 -c 'import sys; sys.stdout.write("synthetic-password" * 131072); sys.stdout.flush()' \\
        | docker login --username AWS --password-stdin fixture-registry
    SH
    output, error, status = Timeout.timeout(10) do
      Open3.capture3(environment, 'bash', '-o', 'pipefail', '-c', script)
    end
    expect(status.success?).to be(true), "#{output}\n#{error}"
    expect(error).not_to include('BrokenPipeError')
  end

  it 'extracts the resolved immutable image without running its entrypoint and retains old fingerprints' do
    output, error, status = invoke('publish-assets', '--image', 'web:moving', '--bucket', 'asset-bucket',
                                   '--profile', 'fixture-profile', '--region', 'us-east-1')
    expect(status.success?).to be(true), "#{output}\n#{error}"
    create = calls.find { |call| call['tool'] == 'docker' && call['args'].first == 'create' }
    expect(create['args']).to include(image_id)
    expect(calls.none? { |call| call['tool'] == 'docker' && call['args'].first.match?(/^(start|run)$/) }).to be(true)
    upload = aws_calls('s3', 'sync').fetch(0)['args']
    expect(upload).to include('s3://asset-bucket/assets', '--profile', 'fixture-profile', '--region', 'us-east-1')
    expect(upload).not_to include('--delete')
    expect_clean_extraction
  end

  it 'returns upload failure and removes extraction resources' do
    _output, error, status = invoke('publish-assets', '--image', 'web:release', '--bucket', 'asset-bucket',
                                    overrides: { 'FIXTURE_UPLOAD_FAIL' => '1' })
    expect(status.exitstatus).to eq(42)
    expect(error).to include('synthetic upload failure')
    expect_clean_extraction
  end

  it 'restricts scratch permissions to the caller' do
    _output, _error, status = invoke('publish-assets', '--image', 'web:release', '--bucket', 'asset-bucket')
    expect(status.success?).to be(true)
    copy = calls.find { |call| call['tool'] == 'docker' && call['args'].first == 'cp' }
    expect(copy['scratch_mode']).to eq(0o700)
  end

  it 'cleans up when publication is interrupted' do
    _output, _error, status = invoke('publish-assets', '--image', 'web:release', '--bucket', 'asset-bucket',
                                     overrides: { 'FIXTURE_UPLOAD_SIGNAL' => '1' })
    expect(status.exitstatus).to eq(143)
    expect_clean_extraction
  end

  it 'supports the legacy string manifest as well as the current Propshaft object format' do
    output, error, status = invoke('publish-assets', '--image', 'web:release', '--bucket', 'asset-bucket',
                                   overrides: { 'FIXTURE_MANIFEST' => 'legacy' })
    expect(status.success?).to be(true), "#{output}\n#{error}"
    expect(aws_calls('s3', 'sync').length).to eq(1)
    expect_clean_extraction
  end

  %w[missing empty invalid missing-file missing-path traversal].each do |manifest|
    it "rejects a #{manifest} asset manifest before uploading" do
      _output, error, status = invoke('publish-assets', '--image', 'web:release', '--bucket', 'asset-bucket',
                                      overrides: { 'FIXTURE_MANIFEST' => manifest })
      expect(status.success?).to be(false)
      expect(error).to include('manifest')
      expect(aws_calls('s3', 'sync')).to be_empty
      expect_clean_extraction
    end
  end

  it 'cleans up if image extraction fails' do
    _output, _error, status = invoke('publish-assets', '--image', 'web:release', '--bucket', 'asset-bucket',
                                     overrides: { 'FIXTURE_COPY_FAIL' => '1' })
    expect(status.success?).to be(false)
    expect(aws_calls('s3', 'sync')).to be_empty
    expect_clean_extraction
  end

  it 'rejects extracted symlinks before the AWS CLI could follow them' do
    _output, error, status = invoke('publish-assets', '--image', 'web:release', '--bucket', 'asset-bucket',
                                    overrides: { 'FIXTURE_MANIFEST' => 'symlink' })
    expect(status.success?).to be(false)
    expect(error).to include('symlink')
    expect(aws_calls('s3', 'sync')).to be_empty
    expect_clean_extraction
  end

  it 'fails before AWS calls if the local image does not exist' do
    _output, _error, status = invoke('publish-assets', '--image', 'absent:release', '--bucket', 'asset-bucket',
                                     overrides: { 'FIXTURE_INSPECT_FAIL' => '1' })
    expect(status.success?).to be(false)
    expect(aws_calls('s3', 'sync')).to be_empty
    expect(Dir.glob(File.join(directory, 'rails-assets.*'))).to be_empty
  end

  %w[web all].each do |service|
    it "publishes #{service} assets after pushes and before any ECS task registration" do
      output, error, status = invoke('deploy-staging', '--service', service, '--profile', 'fixture-profile')
      expect(status.success?).to be(true), "#{output}\n#{error}"
      upload = calls.index { |call| call['tool'] == 'aws' && call['args'][0, 2] == %w[s3 sync] }
      pushes = calls.each_index.select { |index| calls[index]['tool'] == 'docker' && calls[index]['args'].first == 'push' }
      registrations = calls.each_index.select do |index|
        calls[index]['tool'] == 'aws' && calls[index]['args'][0, 2] == %w[ecs register-task-definition]
      end
      expect(upload).to be > pushes.max
      expect(upload).to be < registrations.min
      expect_web_image_identity
      expect_credential_free_builds
    end

    it "blocks all #{service} ECS mutations if asset publication fails" do
      _output, error, status = invoke('deploy-staging', '--service', service,
                                      overrides: { 'FIXTURE_UPLOAD_FAIL' => '1' })
      expect(status.exitstatus).to eq(42)
      expect(error).to include('synthetic upload failure')
      expect(aws_calls('ecs', 'register-task-definition')).to be_empty
      expect(aws_calls('ecs', 'run-task')).to be_empty
      expect(aws_calls('ecs', 'update-service')).to be_empty
      expect_clean_extraction
    end
  end

  it 'deploys worker-only without a bucket or asset publication' do
    output, error, status = invoke('deploy-staging', '--service', 'worker', overrides: { 'FIXTURE_NO_BUCKET' => '1' })
    expect(status.success?).to be(true), "#{output}\n#{error}"
    expect(aws_calls('s3', 'sync')).to be_empty
    expect(aws_calls('ecs', 'update-service').length).to eq(1)
    expect(aws_calls('configure', 'export-credentials')).to be_empty
  end

  it 'keeps --no-deploy restricted to building and pushing images' do
    output, error, status = invoke('deploy-staging', '--no-deploy', overrides: { 'FIXTURE_NO_BUCKET' => '1' })
    expect(status.success?).to be(true), "#{output}\n#{error}"
    expect(aws_calls('s3', 'sync')).to be_empty
    expect(aws_calls('ecs', 'register-task-definition')).to be_empty
  end

  it 'fails closed if the pushed image has no matching repository digest' do
    _output, _error, status = invoke('deploy-staging', '--service', 'web', overrides: { 'FIXTURE_NO_DIGEST' => '1' })
    expect(status.success?).to be(false)
    expect(aws_calls('s3', 'sync')).to be_empty
    expect(aws_calls('ecs', 'register-task-definition')).to be_empty
  end

  it 'fails closed if the captured image has ambiguous repository digests' do
    _output, _error, status = invoke('deploy-staging', '--service', 'web', overrides: { 'FIXTURE_AMBIGUOUS_DIGEST' => '1' })
    expect(status.success?).to be(false)
    expect(aws_calls('s3', 'sync')).to be_empty
    expect(aws_calls('ecs', 'register-task-definition')).to be_empty
  end

  %w[VERSION unexpected-input].each do |file|
    it "refuses dirty local source #{file} before AWS authentication or image construction" do
      File.write(File.join(deployment_source, file), "uncommitted source\n")
      _output, error, status = invoke('deploy-staging', '--service', 'all')
      expect(status.success?).to be(false)
      expect(error).to include('clean committed source')
      expect(calls.select { |call| call['tool'] == 'aws' }).to be_empty
      expect(calls.select { |call| call['args'].first == 'build' }).to be_empty
    end
  end

  it 'builds both images from the selected commit even when the source branch advances' do
    revision = source_revision
    File.write(File.join(deployment_source, 'private-input'), 'ignored private content')
    output, error, status = invoke('deploy-staging', '--service', 'all', overrides: { 'FIXTURE_ADVANCE_SOURCE' => '1' })
    expect(status.success?).to be(true), "#{output}\n#{error}"
    expect(source_revision).not_to eq(revision)
    builds = calls.select { |call| call['tool'] == 'docker' && call['args'].first == 'build' }
    expect(builds.length).to eq(2)
    expect_committed_builds(builds, revision)
    expect(Dir.glob(File.join(directory, 'rails-deploy-source.*'))).to be_empty
  end

  %w[web worker].product(%w[FIXTURE_REVISION FIXTURE_WRONG_DIGEST_IMAGE]).each do |service, input|
    it "refuses #{service} publication and ECS mutations when #{input} disagrees" do
      _output, _error, status = invoke('deploy-staging', '--service', service, overrides: { input => '1' })
      expect(status.success?).to be(false)
      expect(aws_calls('s3', 'sync')).to be_empty
      expect(aws_calls('ecs', 'register-task-definition')).to be_empty
      expect(aws_calls('ecs', 'update-service')).to be_empty
      expect(Dir.glob(File.join(directory, 'rails-deploy-source.*'))).to be_empty
    end
  end

  it 'checks image identity even when ECS deployment is disabled' do
    _output, _error, status = invoke('deploy-staging', '--no-deploy', overrides: { 'FIXTURE_WRONG_DIGEST_IMAGE' => '1' })
    expect(status.success?).to be(false)
    expect(aws_calls('ecs', 'register-task-definition')).to be_empty
  end

  it 'refuses a missing committed image verifier before AWS authentication' do
    git_source(deployment_source, 'rm', 'bin/resolve-release-artifact')
    git_source(deployment_source, '-c', 'user.name=Deployment fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'Missing verifier')
    _output, error, status = invoke('deploy-staging', '--service', 'web')
    expect(status.success?).to be(false)
    expect(error).to include('resolve-release-artifact missing from committed source')
    expect(calls.select { |call| call['tool'] == 'aws' }).to be_empty
    expect(Dir.glob(File.join(directory, 'rails-deploy-source.*'))).to be_empty
  end

  { 'FIXTURE_BUILD_FAIL' => 43, 'FIXTURE_BUILD_SIGNAL' => 143 }.each do |input, code|
    it "removes its committed source context after #{input}" do
      _output, _error, status = invoke('deploy-staging', '--service', 'web', overrides: { input => '1' })
      expect(status.exitstatus).to eq(code)
      expect(aws_calls('ecs', 'register-task-definition')).to be_empty
      expect(Dir.glob(File.join(directory, 'rails-deploy-source.*'))).to be_empty
    end
  end

  it 'keeps the deployment template outside the executable workflow directory' do
    expect(File).not_to exist(File.join(root, '.github', 'workflows', 'deploy.yml'))
    expect(File).to exist(File.join(root, 'templates', 'github', 'workflows', 'deploy-ecs.yml'))
  end

  it 'runs CI publication before registration, migrations and service updates' do
    steps = workflow_steps
    publication = steps.index { |step| step.fetch('run', '').include?('bin/publish-assets') }
    expect(publication).not_to be_nil
    steps.each_with_index do |step, index|
      next unless step.fetch('run', '').match?(/aws ecs (register-task-definition|run-task|update-service)/)

      expect(index).to be > publication
      expect(step['if']).to be_nil
    end
    expect(File.read(File.join(root, 'templates', 'github', 'workflows', 'deploy-ecs.yml'))).not_to match(/export-credentials|--secret|cat > aws_credentials/)
  end

  it 'executes the CI publication and registers the exact image before migrations and replacement' do
    output, error, status = invoke_ci_publication
    expect(status.success?).to be(true), "#{output}\n#{error}"
    expect_web_image_identity
    expect(aws_calls('ecs', 'run-task').length).to eq(1)
    expect(aws_calls('ecs', 'update-service').length).to eq(2)
  end

  it 'stops the executable CI deployment steps after failed publication' do
    _output, error, status = invoke_ci_publication(overrides: { 'FIXTURE_UPLOAD_FAIL' => '1' })
    expect(status.exitstatus).to eq(42)
    expect(error).to include('synthetic upload failure')
    expect(aws_calls('ecs', 'register-task-definition')).to be_empty
    expect(aws_calls('ecs', 'run-task')).to be_empty
    expect(aws_calls('ecs', 'update-service')).to be_empty
  end
end
