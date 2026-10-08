# frozen_string_literal: true

module SmokeConsumer
  # Immutable identity/environment of one exclusively allocated destination.
  class ConsumerTarget
    attr_reader :path, :project, :ownership, :command, :repository, :environment

    # Derive private HOME and Bundler paths from the exclusively allocated consumer context.
    # @param context [Hash{Symbol => Object}] allocated path/project, ownership, command, environment, and repository
    def initialize(context)
      @path, @project, @ownership, @command, base_env, @repository = context.values_at(:path, :project, :ownership, :command, :environment, :repository)
      @environment = base_env.merge('HOME' => File.join(path, 'home'), 'BUNDLE_GEMFILE' => File.join(path, 'Gemfile'),
                                    'BUNDLE_PATH' => File.join(path, 'vendor/bundle'), 'BUNDLE_APP_CONFIG' => File.join(path, '.bundle'))
    end

    # Return the allocated directory basename used as the consumer name.
    # @return [String]
    def name
      File.basename(path)
    end

    # Return private runtime evidence beneath this consumer's ignored temporary directory.
    # @return [String]
    def evidence
      File.join(path, 'tmp/consumer-smoke-evidence')
    end

    # Return the exclusive ownership label for Docker resources.
    # @return [Hash{String => String}]
    def labels
      { LABEL => ownership.token }
    end

    # Return the per-project local application image tag.
    # @return [String]
    def image_tag
      "#{project}-app:local"
    end
  end

  # Configures one private Compose application service from the accepted source settings.
  class AppService
    # Retain mutable accepted service settings, target, phase, and runtime environment.
    # @param settings [Hash] mutable service settings from accepted Compose configuration
    # @param target [ConsumerTarget] allocated consumer identity and environment
    # @param phase [String] web, worker, or db-prepare service phase
    # @param environment [Hash{String => String}] explicit isolated child environment
    def initialize(settings, target, phase, environment)
      @settings = settings
      @target = target
      @phase = phase
      @environment = environment
    end

    # Set the shared image, host UID/GID, private environment, and ownership labels.
    # @return [void]
    def configure
      @settings['image'] = @target.image_tag
      @settings['user'] = "#{Process.uid}:#{Process.gid}"
      @settings.delete('env_file')
      @settings['environment'] = @environment.merge('CONSUMER_SMOKE_PHASE' => @phase, 'RUBYOPT' => '-r/rails/test/runtime/consumer_smoke/aws_tripwire.rb')
      @settings['labels'] = @target.labels
      configure_web if @phase == 'web'
    end

    private

    # Bind web to an ephemeral loopback port and label its built image.
    # @return [void]
    def configure_web
      @settings['ports'] = ['127.0.0.1::3000']
      @settings.fetch('build')['labels'] = @target.labels
    end
  end

  # Configures the owned MySQL service with a synthetic password and loopback binding.
  class MysqlService
    # Retain mutable MySQL settings, the owned target, and its synthetic password.
    # @param settings [Hash] mutable service settings from accepted Compose configuration
    # @param target [ConsumerTarget] allocated consumer identity and environment
    # @param password [String] synthetic local MySQL password
    def initialize(settings, target, password)
      @settings = settings
      @target = target
      @password = password
    end

    # Require the existing MySQL image and configure a synthetic-password TCP healthcheck.
    # @return [void]
    def configure
      @target.command.call('docker', 'image', 'inspect', @settings.fetch('image'), timeout: 15)
      @settings['ports'] = ['127.0.0.1::3306']
      @settings['labels'] = @target.labels
      @settings['environment'] = { 'MYSQL_ROOT_PASSWORD' => @password, 'MYSQL_ROOT_HOST' => '%' }
      @settings['healthcheck']['test'] = ['CMD-SHELL', 'MYSQL_PWD=$$MYSQL_ROOT_PASSWORD mysql --protocol=TCP --host=127.0.0.1 --user=root --execute "SELECT 1"']
    end
  end

  # Writes an exclusive private Compose overlay with ownership labels on resources.
  class ComposeConfiguration
    # Retain the target and synthetic database adapter for overlay generation.
    # @param target [ConsumerTarget] allocated consumer identity and environment
    # @param database [LocalDatabase] owned synthetic database settings
    def initialize(target, database)
      @target = target
      @database = database
    end

    # Read accepted Compose settings and exclusively write the private labeled overlay.
    # @return [Integer]
    def write
      path = @target.path
      config = YAML.safe_load_file(File.join(path, 'compose.yaml'), aliases: true)
      configure_services(config.fetch('services'))
      labels = @target.labels
      config['volumes'] = { 'mysql_data' => { 'labels' => labels } }
      config['networks'] = { 'default' => { 'labels' => labels } }
      File.open(File.join(path, 'compose.smoke.yml'), File::WRONLY | File::CREAT | File::EXCL, 0o600) { |output| output.write(YAML.dump(config)) }
    end

    private

    # Configure web, worker, preparation, and database services for this target.
    # @param services [Hash] accepted Compose services map
    # @return [void]
    def configure_services(services)
      environment = @database.runtime_environment
      %w[web worker db-prepare].each { |phase| AppService.new(services.fetch(phase), @target, phase, environment).configure }
      MysqlService.new(services.fetch('db'), @target, @database.password).configure
    end
  end

  # Each inspection is live; identifiers are normalized only within that observation.
  class ComposeRuntime
    # Retain the allocated target used by every Compose command and inspection.
    # @param target [ConsumerTarget] allocated consumer identity and environment
    def initialize(target)
      @target = target
    end

    # Run Docker Compose argv with the private project, overlay, environment, and cwd.
    # Anonymous positional arguments are forwarded as Docker Compose argv.
    # @return [Array(String, CommandExit)]
    def call(*)
      @target.command.call('docker', 'compose', '-p', @target.project, '-f', 'compose.smoke.yml', *,
                           env: @target.environment, chdir: @target.path)
    end

    # Inspect the actual service container, verify labels, and register its immutable ID.
    # @param service [String] Compose service name
    # @return [Hash]
    # @raise [Error] service container is absent or has foreign labels
    def container(service)
      output, = call('ps', '--all', '--quiet', service)
      identifier = output.strip
      raise Error, "Missing actual #{service} container" if identifier.empty?

      text, = @target.command.call('docker', 'container', 'inspect', identifier, timeout: 10)
      data = JSON.parse(text).fetch(0)
      verify_and_register(data)
      data
    end

    # Return a live port mapping only after verifying its host is loopback.
    # @param service [String] Compose service name
    # @param port [String] container port/protocol key
    # @return [Hash{String => String}]
    # @raise [Error] port is not bound to loopback
    def binding(service, port)
      binding = container(service).fetch('NetworkSettings').fetch('Ports').fetch(port).fetch(0)
      raise Error, 'Service is not bound to loopback' unless binding.fetch('HostIp') == '127.0.0.1'

      binding
    end

    # Build the shared image, start web/worker, and check preparation and image identity.
    # @return [void]
    # @raise [Error] preparation failed or application image identities differ
    def start
      call('build', 'web')
      register_image
      call('up', '-d', 'web', 'worker')
      verify_preparation
      raise Error, 'Web/worker do not share one image' unless container('web')['Image'] == container('worker')['Image']
    end

    # Stop actual web and worker before closing the AWS observation window.
    # @return [Array(String, CommandExit)]
    def stop_application
      call('stop', '--timeout', '10', 'web', 'worker')
    end

    private

    # Verify token/project labels and register a previously unseen container ID.
    # @param data [Hash] manifest, Docker observation, or committed input data used by this operation
    # @return [void]
    def verify_and_register(data)
      labels = data.fetch('Config').fetch('Labels')
      owner = @target.ownership
      project = @target.project
      raise Error, 'Container ownership mismatch' unless labels[LABEL] == owner.token && labels['com.docker.compose.project'] == project

      identifier = data.fetch('Id')
      owner.register_resource('container', identifier, data.fetch('Name').delete_prefix('/'), project) unless owner.read.fetch('resources').any? { |entry| entry['id'] == identifier }
    end

    # Record the actual built image ID under its owned local tag.
    # @return [void]
    def register_image
      tag = @target.image_tag
      text, = @target.command.call('docker', 'image', 'inspect', tag, timeout: 10)
      @target.ownership.register_resource('image', JSON.parse(text).fetch(0).fetch('Id'), tag, @target.project)
    end

    # Require the preparation container to have exited with status zero.
    # @return [void]
    def verify_preparation
      prepared = container('db-prepare').fetch('State')
      raise Error, 'Preparation service failed' unless prepared['Status'] == 'exited' && prepared['ExitCode'].zero?
    end
  end

  # Creates a synthetic local user and grants the eight development/test schemas.
  class LocalDatabase
    attr_reader :password

    # Synthetic local MySQL user, separate from root used for grants.
    USER = 'smoke'

    # Retain the target/runtime and generate a fresh synthetic database password.
    # @param target [ConsumerTarget] allocated consumer identity and environment
    # @param runtime [ComposeRuntime] owned Compose command/inspection adapter
    def initialize(target, runtime)
      @target = target
      @runtime = runtime
      @password = SecureRandom.hex(24)
    end

    # Return the synthetic local database account name.
    # @return [String]
    def user
      self.class::USER
    end

    # Build the four-database app environment with AWS bootstrap, SSL, and IAM disabled.
    # @return [Hash{String => String}]
    def runtime_environment
      name = @target.name
      { 'RAILS_ENV' => 'development', 'DATABASE_NAME' => name, 'DATABASE_USER' => user,
        'DATABASE_PASSWORD' => password, 'PRIMARY_DB_HOST' => 'db', 'DATABASE_PORT' => '3306',
        'DATABASE_SSL' => 'false', 'DATABASE_IAM_AUTH' => 'false', 'AWS_BOOTSTRAP_ENABLED' => 'false',
        'AWS_EC2_METADATA_DISABLED' => 'true', 'CONSUMER_SMOKE_TOKEN' => @target.ownership.token,
        'CONSUMER_SMOKE_NAME' => name, 'CONSUMER_SMOKE_EVIDENCE' => '/rails/tmp/consumer-smoke-evidence' }
    end

    # List the primary, queue, cache, and cable schemas for development and test.
    # @return [Array<String>]
    def schema_names
      name = @target.name
      ['', '_queue', '_cache', '_cable'].flat_map { |suffix| ["#{name}#{suffix}", "#{name}#{suffix}_test"] }
    end

    # Create the synthetic user and grant all eight physical schema names through root.
    # @return [String]
    def grant
      statements = ["CREATE USER '#{user}'@'%' IDENTIFIED BY '#{password}'"]
      statements.concat(schema_names.map { |name| "GRANT ALL ON \u0060#{name}\u0060.* TO '#{user}'@'%'" })
      sql(statements.join(';'), user: 'root')
    end

    # Query actual MySQL schema names and require the expected eight physical schemas.
    # @return [Array<String>]
    # @raise [Error] one or more expected schemas are missing
    def verify_schemas
      expected = schema_names
      listed = expected.map { |name| "'#{name}'" }.join(',')
      names = sql("SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME IN (#{listed}) ORDER BY SCHEMA_NAME").split
      raise Error, 'Eight physical development/test schemas missing' unless names.sort == expected.sort

      names
    end

    # Execute TCP MySQL inside the owned database container with password in the child environment.
    # @param statement [String] SQL for the owned local database
    # @param user [String] local MySQL account name
    # @return [String]
    def sql(statement, user: self.user)
      identifier = @runtime.container('db').fetch('Id')
      output, = @target.command.call('docker', 'exec', '-e', 'MYSQL_PWD', identifier, 'mysql', '--protocol=TCP', '--host=127.0.0.1', "--user=#{user}",
                                     '--batch', '--skip-column-names', '--execute', statement, env: @target.environment.merge('MYSQL_PWD' => password), timeout: 15)
      output.strip
    end

    # Replace the database host/port with its live loopback binding for host setup.
    # @return [Hash{String => String}]
    def setup_environment
      binding = @runtime.binding('db', '3306/tcp')
      runtime_environment.merge('PRIMARY_DB_HOST' => '127.0.0.1', 'DATABASE_PORT' => binding.fetch('HostPort'),
                                'CONSUMER_SMOKE_PHASE' => 'setup', 'CONSUMER_SMOKE_EVIDENCE' => @target.evidence)
    end
  end

  # Retains fixed setup classifications without persisting private command output.
  class SetupFailure
    # Exact emitted banners identify the last announced phase, not phase success.
    PHASES = { '== Installing locked dependencies ==' => 'locked_dependencies',
               '== Installing configured hooks (not a provider-gate verdict) ==' => 'configured_hooks',
               '== Preparing databases ==' => 'preparing_databases' }.freeze

    # Retain completed output and its real native status until the sanitized receipt is written.
    # @param output [String] bounded command output, never included in a receipt
    # @param status [CommandExit] actual executed setup exit/signal status
    def initialize(output, status)
      @output = output.b
      @status = status
    end

    # Publish only fixed classifications, actual status and output fingerprints in the private root.
    # @param ownership [Ownership] exclusively allocated private root
    # @param name [String] registered consumer name
    # @param attempt [Integer] first or second setup invocation
    # @return [Integer] bytes written by the original exclusive publication primitive
    def record(ownership, name, attempt)
      ownership.write_once("setup-failure-#{name.tr('_', '-')}-#{attempt}.json", observation.merge('attempt' => attempt))
    end

    private

    # Describe completed capture without retaining output, arguments, environment or paths.
    # @return [Hash{String => Object}] closed sanitized observation
    def observation
      { 'exitstatus' => @status.exitstatus, 'termsig' => @status.termsig,
        'output_bytes' => @output.bytesize, 'output_sha256' => Digest::SHA256.hexdigest(@output) }.merge(classifications)
    end

    # Scan one bounded line at a time, retaining only the last fixed classification.
    # @return [Hash{String => Object}] announced phase and closed error enum, or unknown
    def classifications
      phase = nil
      error = nil
      @output.each_line do |line|
        text = line.delete_suffix("\n")
        phase = PHASES[text] || phase
        error = classify_error(text) || error
      end
      { 'emitted_phase' => phase, 'setup_error' => error }
    end

    # Accept only a complete fixed-executable failure line; arbitrary error text remains unretained.
    # @param line [String] one binary output line without its newline
    # @return [Hash, nil] closed executable enum and reported status, or unknown
    def classify_error(line)
      match = /\Asetup: (bun|bundle|git|rails|lefthook|node) failed \(exit ([0-9]{1,3})\)\z/n.match(line)
      return unless match

      reported = match[2].to_i
      return unless (0..255).cover?(reported)

      { 'executable' => match[1], 'reported_status' => reported }
    end
  end

  # Records executable Lefthook wrappers and hashes without proving hook gate behavior.
  class HookEvidence
    # Retain the target whose installed hook wrappers will be inspected.
    # @param target [ConsumerTarget] allocated consumer identity and environment
    def initialize(target)
      @target = target
    end

    # Hash configured executable Lefthook wrappers; this does not execute their gates.
    # @return [Hash{String => String}]
    def verify
      config = YAML.safe_load_file(File.join(@target.path, 'lefthook.yml'), aliases: true)
      config.keys.grep(/\A[a-z]+(?:-[a-z]+)+\z/).to_h { |hook| [hook, hook_hash(hook)] } # rubocop:disable Rails/IndexWith -- standalone stdlib receipt.
    end

    private

    # Require an executable wrapper containing Lefthook and return its SHA-256 digest.
    # @param hook [String] configured Git hook name
    # @return [String]
    # @raise [Error] configured executable Lefthook wrapper is missing
    def hook_hash(hook)
      path = File.join(@target.path, '.git/hooks', hook)
      raise Error, "Configured hook missing: #{hook}" unless File.file?(path) && File.executable?(path) && File.read(path).include?('lefthook')

      Digest::SHA256.file(path).hexdigest
    end
  end

  # Records actual loopback HTTP responses and checks the renamed home rendering.
  class HttpEvidence
    # Retain the target and runtime used to discover actual loopback web bindings.
    # @param target [ConsumerTarget] allocated consumer identity and environment
    # @param runtime [ComposeRuntime] owned Compose command/inspection adapter
    def initialize(target, runtime)
      @target = target
      @runtime = runtime
    end

    # Require 200 for home and health and the renamed display name in saved home HTML.
    # @return [Hash{String => Integer}]
    # @raise [Error] renamed home content is absent or HTTP deadline expires
    def verify
      binding = @runtime.binding('web', '3000/tcp')
      responses = %w[/ /up].to_h { |route| [route, response(route, binding)] } # rubocop:disable Rails/IndexWith -- standalone stdlib CLI.
      display = @target.name.split('_').map(&:capitalize).join(' ')
      raise Error, 'Named home rendering missing' unless File.read(File.join(@target.evidence, 'home.html')).include?(display)

      responses
    end

    private

    # Poll one real loopback URL, save its body, and return its successful 200 status.
    # @param route [String] home or health route
    # @param binding [Hash{String => String}] verified loopback Docker port mapping
    # @return [Integer]
    def response(route, binding)
      status = nil
      file = File.join(@target.evidence, route == '/' ? 'home.html' : 'up.html')
      url = "http://127.0.0.1:#{binding.fetch('HostPort')}#{route}"
      command = @target.command
      Deadline.new(120, ceiling: command.deadline).poll("HTTP #{route} deadline exceeded", interval: 0.25) do
        status, result = command.capture('curl', '--silent', '--show-error', '--max-time', '5', '--user-agent', 'Mozilla/5.0 Chrome/130.0.0.0 Safari/537.36',
                                         '--output', file, '--write-out', '%{http_code}', url, timeout: 6) # rubocop:disable Style/FormatStringToken -- curl syntax.
        result.success? && status == '200'
      end
      status.to_i
    end
  end

  # Reads tripwire events and distinguishes SDK/stub activity from blocked provider access.
  class AwsEvidence
    # Tripwire categories reported individually, including zero-count categories.
    KINDS = %w[provider_transport_attempt sdk_request stub_handled credential_lookup socket_attempt http_attempt].freeze

    # Parse every JSON-line event from the consumer AWS tripwire evidence file.
    # @param path [String] owned filesystem path
    def initialize(path)
      @events = File.readlines(File.join(path, 'aws.jsonl')).map { |line| JSON.parse(line) }
    end

    # Reject blocked events or setup SDK requests and retain all observed event categories.
    # @return [Hash{String => Object}]
    # @raise [Error] blocked provider access or setup SDK activity was observed
    def verify
      raise Error, 'AWS lookup/transport tripwire reached' if @events.any? { |event| event['blocked'] || (event['phase'] == 'setup' && event['kind'] == 'sdk_request') }

      { 'aws_events' => @events, 'aws_counts' => counts, 'aws_observed_until' => 'actual_web_worker_stop' }
    end

    private

    # Count every known event category, retaining zeros rather than omitting categories.
    # @return [Hash{String => Integer}]
    def counts
      grouped = @events.group_by { |event| event['kind'] }.transform_values(&:length)
      KINDS.to_h { |kind| [kind, grouped.fetch(kind, 0)] } # rubocop:disable Rails/IndexWith -- standalone stdlib receipt.
    end
  end

  # Validates the actual Active Job and provider identities returned by the web enqueuer.
  class EnqueuedJob
    attr_reader :identity

    # Find the actual enqueuer receipt and validate its job UUID and numeric provider ID.
    # @param output [String] actual command or process-observer output
    # @raise [Error] actual enqueued job identity is missing or malformed
    def initialize(output)
      line = output.lines.find { |text| text.start_with?('CONSUMER_JOB=') }
      raise Error, 'No actual enqueued job identity' unless line

      @identity = JSON.parse(line.delete_prefix('CONSUMER_JOB='))
      raise Error, 'Malformed job identity' unless @identity['job_id'].match?(/\A[a-f0-9-]{36}\z/) && @identity['provider_id'].to_s.match?(/\A[0-9]+\z/)
    end

    # Build the exact queue-row query requiring finished state and no failed execution.
    # @param name [String] name used by this operation
    # @return [String]
    def completion_sql(name)
      "SELECT COUNT(*) FROM \u0060#{name}_queue\u0060.solid_queue_jobs j " \
        "WHERE j.id=#{@identity['provider_id']} AND j.active_job_id='#{@identity['job_id']}' AND j.finished_at IS NOT NULL " \
        "AND NOT EXISTS (SELECT 1 FROM \u0060#{name}_queue\u0060.solid_queue_failed_executions f WHERE f.job_id=j.id)"
    end
  end

  # Correlates a worker side effect with a finished queue row and actual Worker process.
  class WorkerCompletion
    # Retain target/runtime/database adapters for enqueue and worker correlation.
    # @param target [ConsumerTarget] allocated consumer identity and environment
    # @param runtime [ComposeRuntime] owned Compose command/inspection adapter
    # @param database [LocalDatabase] owned synthetic database settings
    def initialize(target, runtime, database)
      @target = target
      @runtime = runtime
      @database = database
    end

    # Wait for both worker side effect and finished queue row, then verify worker identity.
    # @return [Hash{String => Object}]
    def complete
      job = enqueue
      marker_path = File.join(@target.evidence, 'worker-job.json')
      Deadline.new(60, ceiling: @target.command.deadline).poll('real worker job completion deadline exceeded', interval: 0.25) do
        File.file?(marker_path) && @database.sql(job.completion_sql(@target.name)) == '1'
      end
      marker = JSON.parse(File.read(marker_path))
      worker = @runtime.container('worker')
      identity = job.identity
      verify_worker(marker, identity, worker)
      identity.merge('worker_container' => worker.fetch('Id'), 'worker_pid' => marker.fetch('pid'), 'finished' => true, 'side_effect' => marker)
    end

    private

    # Enqueue the fixture through the actual web container and parse its returned job identities.
    # @return [EnqueuedJob]
    def enqueue
      script = "job = ConsumerSmokeFixtureJob.perform_later(#{@target.ownership.token.inspect}, #{@target.name.inspect}); " \
               "abort 'enqueue failed' unless job.successfully_enqueued?; " \
               "puts 'CONSUMER_JOB=' + JSON.generate(job_id: job.job_id, provider_id: job.provider_job_id)"
      output, = @runtime.call('exec', '-T', '-e', 'CONSUMER_SMOKE_PHASE=enqueuer', 'web', 'bin/rails', 'runner', script)
      EnqueuedJob.new(output)
    end

    # Match token/name/job/hostname and require a queue Worker process with the marker PID.
    # @param marker [Hash] actual worker side-effect receipt
    # @param job [Hash] validated enqueued job identities
    # @param worker [Hash] live inspected worker container
    # @return [void]
    # @raise [Error] side effect or actual queue Worker identity does not match
    def verify_worker(marker, job, worker)
      name = @target.name
      expected = [@target.ownership.token, name, job['job_id'], worker.fetch('Config').fetch('Hostname')]
      raise Error, 'Synthetic job side effect is not from actual worker' unless marker.values_at('token', 'name', 'job_id', 'hostname') == expected

      pid = Integer(marker.fetch('pid'))
      processes = @database.sql("SELECT COUNT(*) FROM \u0060#{name}_queue\u0060.solid_queue_processes WHERE kind='Worker' AND pid=#{pid}")
      raise Error, 'No matching actual Solid Queue Worker process' unless processes.to_i.positive?
    end
  end

  # Initializes and exercises one renamed consumer inside an already armed ownership scope.
  class Consumer
    # Run the two-consumer batch using validated public CLI options.
    # @param options [Hash{Symbol => Object}] explicit command or public CLI options
    # @return [void]
    def self.run(options)
      Batch.new(options).run
    end

    # Build the target, Compose runtime, and synthetic database for one allocated consumer.
    # @param context [Hash{Symbol => Object}] allocated path/project, ownership, command, environment, and repository
    def initialize(context)
      @target = ConsumerTarget.new(context)
      @runtime = ComposeRuntime.new(@target)
      @database = LocalDatabase.new(@target, @runtime)
    end

    # Rename, prepare, run setup twice, exercise web/worker, and persist the owned consumer receipt.
    # @return [Hash{String => Object}]
    def run
      renamed = initialize_tree
      prepare_database
      setup_twice
      hooks = HookEvidence.new(@target).verify
      outcomes = exercise_application
      result = renamed.merge(outcomes).merge('schemas' => @database.verify_schemas, 'database_user' => @database.user, 'setup_runs' => 2, 'hooks' => hooks)
      result.merge!(AwsEvidence.new(@target.evidence).verify)
      @target.ownership.write_once("consumer-#{@target.name.tr('_', '-')}.json", result)
      result
    end

    private

    # Rename admitted files and initialize main in a verified consumer-owned Git common directory.
    # @return [Hash{String => Object}]
    def initialize_tree
      path = @target.path
      command = @target.command
      renamed = Rename.apply(path, @target.name, @target.repository)
      environment = @target.environment
      Dir.mkdir(environment.fetch('HOME'), 0o700)
      command.call('git', 'init', '--initial-branch=main', path, env: environment, timeout: 10)
      common, = command.call('git', 'rev-parse', '--path-format=absolute', '--git-common-dir', env: environment, chdir: path, timeout: 10)
      raise Error, 'Consumer Git common directory is foreign' unless File.realpath(common.strip) == File.join(path, '.git')

      renamed
    end

    # Install the fixture, write the overlay, await healthy owned MySQL, and grant schemas.
    # @return [void]
    def prepare_database
      install_fixture
      ComposeConfiguration.new(@target, @database).write
      @runtime.call('up', '-d', 'db')
      Deadline.new(120, ceiling: @target.command.deadline).poll('owned MySQL readiness deadline exceeded', interval: 0.25) do
        @runtime.container('db').dig('State', 'Health', 'Status') == 'healthy'
      end
      @database.grant
    end

    # Copy the accepted fixture into this consumer after creating private evidence storage.
    # @return [void]
    def install_fixture
      evidence = @target.evidence
      parent = File.dirname(evidence)
      FileUtils.mkdir_p(parent, mode: 0o700)
      raise Error, 'Foreign fixture evidence parent' unless File.realpath(parent) == parent && !File.symlink?(parent)

      Dir.mkdir(evidence, 0o700)
      path = @target.path
      source = File.join(path, 'test/runtime/consumer_smoke/fixture_job.rb')
      raise Error, 'Essential prerequisite: accepted smoke fixture is absent from source commit' unless File.file?(source)

      FileUtils.copy_file(source, File.join(path, 'app/jobs/consumer_smoke_fixture_job.rb'))
    end

    # Run bin/setup --skip-server twice with the live loopback database environment.
    # @return [void]
    def setup_twice
      environment = @target.environment.merge(@database.setup_environment)
      2.times { |attempt| run_setup(environment, attempt + 1) }
    end

    # Preserve a sanitized completed failure before the original nonzero refusal and owned cleanup.
    # @param environment [Hash{String => String}] existing live local database and tool environment
    # @param attempt [Integer] first or second setup invocation
    # @return [void]
    def run_setup(environment, attempt)
      output, status = @target.command.capture('bin/setup', '--skip-server', env: environment, chdir: @target.path)
      begin
        SetupFailure.new(output, status).record(@target.ownership, @target.name, attempt) unless status.success?
      ensure
        CommandStatus.new('bin/setup', status).require_success
      end
    end

    # Start actual web/worker, collect HTTP/job receipts, and stop application processes.
    # @return [Hash{String => Object}]
    def exercise_application
      @runtime.start
      http = HttpEvidence.new(@target, @runtime).verify
      job = WorkerCompletion.new(@target, @runtime, @database).complete
      @runtime.stop_application
      { 'http' => http, 'job' => job }
    end
  end

  # Validates the two consumer names, committed source ref, timeout, and repository identity.
  class BatchOptions
    # Retain public CLI values for validation and accepted-source selection.
    # @param values [Hash{Symbol => Object}] public CLI option values
    def initialize(values)
      @values = values
    end

    # Read the requested two consumer names.
    # @return [Array<String>]
    def names
      @values.fetch(:names)
    end

    # Read the committed source selector, validated separately.
    # @return [String]
    def source_ref
      @values.fetch(:source)
    end

    # Read the whole-run timeout in seconds.
    # @return [Integer]
    def timeout
      @values.fetch(:timeout)
    end

    # Require two safe distinct names, a bounded timeout, and HEAD or a hexadecimal commit ref.
    # @return [void]
    # @raise [Error] names, timeout, or source ref violate the bounded CLI contract
    def validate
      destinations = names
      raise Error, 'Exactly two distinct safe consumer names are required' unless destinations.size == 2 && destinations.uniq.size == 2 && destinations.all? do |name|
        name.match?(/\A[a-z][a-z0-9_]{2,39}\z/)
      end
      raise Error, 'Timeout must be between 1 and 3600 seconds' unless (1..3600).cover?(timeout)
      raise Error, 'Unsafe source ref' unless source_ref.match?(/\A(?:HEAD|[a-f0-9]{7,40})\z/)
    end

    # Choose the explicit or configured repository identity and validate its syntax.
    # @param config [Hash] accepted Lisa configuration
    # @return [String]
    # @raise [Error] repository identity is unsafe
    def repository(config)
      github = config.fetch('github')
      identity = @values[:repository] || "#{github.fetch('org')}/#{github.fetch('repo')}"
      raise Error, 'Unsafe repository identity' unless identity.match?(%r{\A[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9][A-Za-z0-9_.-]*\z})

      identity
    end
  end

  # Resolves a committed source and checks its toolchain and Docker prerequisites.
  class AcceptedSource
    attr_reader :root, :commit, :metadata, :repository

    # Locate the source repository and create a bounded preflight command executor.
    # @param options [BatchOptions] validated batch options
    def initialize(options)
      @options = options
      @root = File.expand_path('../..', __dir__)
      @command = Command.new(timeout: 60)
      @commit = nil
      @metadata = nil
      @repository = nil
    end

    # Resolve the commit, validate accepted tool/lifecycle metadata, and check existing Docker prerequisites.
    # @return [void]
    def preflight
      @options.validate
      source, = @command.call('git', 'rev-parse', '--verify', "#{@options.source_ref}^{commit}", chdir: root, timeout: 10)
      @commit = source.strip
      data = source_files
      @metadata = Toolchain.metadata(JSON.parse(data.fetch('package.json')), JSON.parse(data.fetch('package-lock.json')), data.fetch('.ruby-version'), data.fetch('Gemfile.lock'))
      Toolchain.require_install_only(@metadata)
      Toolchain.require_ruby(@metadata)
      @repository = @options.repository(JSON.parse(data.fetch('.lisa.config.json')))
      check_docker(data)
    end

    # Read a tar archive of the resolved commit without copying the worktree.
    # @param command [Command] bounded argv executor
    # @return [String]
    def archive(command)
      text, = command.call('git', 'archive', '--format=tar', commit, chdir: root, timeout: 20)
      text
    end

    private

    # Read the six committed metadata/Compose inputs with git show.
    # @return [Hash{String => String}]
    def source_files
      %w[package.json package-lock.json .ruby-version Gemfile.lock .lisa.config.json compose.yaml].to_h do |name|
        text, = @command.call('git', 'show', "#{commit}:#{name}", chdir: root, timeout: 10)
        [name, text]
      end
    end

    # Probe actual Docker/Compose and require the committed database image to be present.
    # @param data [Hash] manifest, Docker observation, or committed input data used by this operation
    # @return [void]
    def check_docker(data)
      @command.call('docker', 'version', '--format', '{{.Server.Version}}', timeout: 15)
      @command.call('docker', 'compose', 'version', '--short', timeout: 10)
      image = YAML.safe_load(data.fetch('compose.yaml'), aliases: true).fetch('services').fetch('db').fetch('image')
      @command.call('docker', 'image', 'inspect', image, timeout: 15)
    end
  end

  # Prepares private tools and records the digest of the accepted committed archive.
  class ConsumerInputs
    attr_reader :archive, :environment

    # Create private tool HOME, prepare accepted tools, archive the commit, and record its digest.
    # @param source [AcceptedSource] preflight-validated committed source
    # @param ownership [Ownership] exclusive validated ownership scope
    # @param command [Command] bounded argv executor
    def initialize(source, ownership, command)
      home = File.join(ownership.root, 'home')
      Dir.mkdir(home, 0o700)
      @environment = Toolchain.new(command, source.metadata, home).consumer_environment
      @archive = source.archive(command)
      ownership.write_once('archive.json', 'source' => source.commit, 'sha256' => Digest::SHA256.hexdigest(archive))
    end
  end

  # App-specific authority is armed before any copy, tool download or Docker allocation.
  class ConsumerRun
    attr_reader :ownership, :command, :inputs

    # Allocate an armed ownership scope, yield it, and always request cleanup on exit.
    # @param source [AcceptedSource] preflight-validated committed source
    # @param options [BatchOptions] validated batch options
    # @yield [run] allocated ownership scope
    # @yieldparam run [ConsumerRun] armed consumer run
    # @return [Object] caller block result
    def self.open(source, options)
      run = new(source, options)
      run.allocate
      yield run
    ensure
      run&.close
    end

    # Retain source/options before any ownership, cleanup authority, or inputs are allocated.
    # @param source [AcceptedSource] preflight-validated committed source
    # @param options [BatchOptions] validated batch options
    def initialize(source, options)
      @source = source
      @options = options
      @ownership = nil
      @authority = nil
      @command = nil
      @inputs = nil
    end

    # Create ownership and arm detached cleanup before preparing tools or the committed archive.
    # @return [void]
    def allocate
      base = private_base
      seconds = @options.timeout
      @ownership = Ownership.create(base, timeout: seconds)
      @authority = CleanupAuthority.arm(@ownership)
      @command = Command.new(timeout: seconds, ownership: @ownership, ceiling: @ownership.read.fetch('deadline'))
      @inputs = ConsumerInputs.new(@source, @ownership, @command)
    end

    # Allocate a distinct name, export the accepted archive, and run its actual consumer.
    # @param name [String] name used by this operation
    # @return [Hash{String => Object}]
    def build_consumer(name)
      path, project = @ownership.register_consumer(name)
      Rename.export(@inputs.archive, path, source: @source.commit)
      Consumer.new(path: path, project: project, ownership: @ownership, command: @command,
                   environment: @inputs.environment, repository: @source.repository).run
    end

    # Finish cleanup only when both ownership and its authority have been allocated.
    # @return [Hash, nil]
    def close
      CleanupAuthority.finish(@ownership, @authority) if @ownership && @authority
    end

    private

    # Require a nonsymlink ignored temporary base before creating private storage.
    # @return [String]
    def private_base
      root = @source.root
      temporary = File.join(root, 'tmp')
      raise Error, 'Symlinked temporary base refused' if File.symlink?(temporary)

      base = File.join(temporary, 'consumer-smoke')
      Command.new(timeout: 10).call('git', 'check-ignore', '-q', File.join(base, 'probe'), chdir: root, timeout: 10)
      FileUtils.mkdir_p(base, mode: 0o700)
      base
    end
  end

  # Runs two consumers and publishes a receipt only after owned cleanup has completed.
  class Batch
    # Wrap public CLI options and create the committed-source preflight adapter.
    # @param options [Hash{Symbol => Object}] explicit command or public CLI options
    def initialize(options)
      @options = BatchOptions.new(options)
      @source = AcceptedSource.new(@options)
    end

    # Preflight and execute the batch, then print its JSON receipt after cleanup succeeds.
    # @return [Integer]
    def run
      @source.preflight
      result = ConsumerRun.open(@source, @options) { |run| execute(run) }
      $stdout.write("#{JSON.generate(result)}\n") # rubocop:disable Rails/Output -- public CLI receipt after successful owned cleanup.
    end

    private

    # Run both allocated consumers and persist results with provider-gate proof explicitly false.
    # @param run [ConsumerRun] allocated scope armed with independent cleanup
    # @return [Hash{String => Object}]
    def execute(run)
      owner = run.ownership
      commit = @source.commit
      results = @options.names.map { |name| run.build_consumer(name) }
      owner.write_once('result.json', 'source' => commit, 'metadata' => @source.metadata, 'consumers' => results,
                                      'provider_gate_verified' => false, 'no_provider_writes' => true)
      { 'source' => commit, 'evidence_root' => owner.root, 'consumers' => results }
    end
  end
end
