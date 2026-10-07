# frozen_string_literal: true

require 'bundler/setup'
require 'json'
require 'open3'
require 'securerandom'
require 'tmpdir'
require 'fileutils'
require 'rbconfig'
require 'socket'

# Developer/CI fixture: owns a fresh disposable server, never adopts an existing DB.
class OwnedMigrationMysql
  IMAGE = 'mysql:8.4.11@sha256:6ea90827b1100f8f2ae306a539f86d2c264a26ed435a2a9f75551dd5c3aeb242'
  ROOT = File.expand_path('../../..', __dir__)
  ROLES = %w[primary primary_replica queue cache cable].freeze
  attr_reader :receipt, :receipt_path, :observations

  def initialize
    @token = SecureRandom.hex(6)
    @name = "railsstarter77-#{@token}"
    @labels = { 'lisa.owner_token' => @token, 'lisa.work_item' => 'CodySwannGT/railsstarter#77',
                'test.run_id' => "rspec-#{SecureRandom.uuid}" }
    @docker = find_docker
    @observations = { run_id: @labels.fetch('test.run_id'), resources_absent: false }
    @created = []
    at_exit { close unless @created.empty? || @close_attempted }
  end

  def start
    observations[:daemon] = JSON.parse(docker('version', '--format', '{{json .Server}}')).slice('Version', 'Os', 'Arch')
    verify_image

    create_resources
    container = verify_container
    @port = Integer(container.fetch('NetworkSettings').fetch('Ports').fetch('3306/tcp').fetch(0).fetch('HostPort'))
    observations[:native_preaccess] = OwnedMigrationPreaccess.validate!(environment)
    physical = wait_for_server
    write_receipt(physical)
    self
  rescue StandardError, Interrupt, SystemExit
    close
    raise
  end

  def environment
    result = ENV.to_h.reject do |key, _|
      key.match?(/\A(?:DATABASE_|PRIMARY_DB_|AWS_|SECRET_KEY_BASE|RAILS_|RACK_|OTEL_|CLOUDFRONT_)/) || key.end_with?('_DATABASE_URL')
    end
    raise 'SAFETY_ASSURED is forbidden' if result.key?('SAFETY_ASSURED')

    result['PATH'] = [File.dirname(@docker), result.fetch('PATH')].uniq.join(File::PATH_SEPARATOR)
    result.merge('RAILS_ENV' => 'test', 'RACK_ENV' => 'test', 'DATABASE_NAME' => "owned77_#{@token}_app",
                 'PRIMARY_DB_HOST' => '127.0.0.1', 'DATABASE_REPLICA_HOST' => '127.0.0.1', 'DATABASE_PORT' => @port.to_s,
                 'DATABASE_USER' => 'root', 'DATABASE_IAM_AUTH' => 'false', 'DATABASE_SSL' => 'false',
                 'AWS_EC2_METADATA_DISABLED' => 'true', 'AWS_BOOTSTRAP_ENABLED' => 'false', 'SECRET_KEY_BASE_DUMMY' => '1')
  end

  def prepare_application
    verify_physical!
    create_application_databases
    app_env = environment.merge('DATABASE_USER' => @application_user, 'DATABASE_PASSWORD' => @application_password)
    observations[:native_preaccess] = OwnedMigrationPreaccess.validate!(app_env)
    @databases.each do |database|
      actual = sql("USE `#{database}`; SELECT DATABASE(), @@server_uuid; SHOW TABLES;").strip.split("\t")
      raise 'Fresh physical application schema mismatch' unless actual == [database, receipt.fetch('server_uuid')]
    end
    observations[:application_connections] = OwnedMigrationPreaccess.verify_connections!(app_env, receipt)
    observations[:application_databases] = @databases
    observations[:resolved_roles] = ROLES
    app_env
  end

  def close
    @close_attempted = true
    if @receipt && !@created.empty?
      verify_physical!
      observations[:schemas_before_cleanup] = sql('SHOW DATABASES;').lines.map(&:strip)
    end
    errors = @created.reverse.filter_map { |kind, identity| remove_owned_resource(kind, identity) }
    docker('version', '--format', '{{.Server.Version}}') unless @created.empty?
    raise "Owned cleanup failed: #{errors.join(',')}" unless errors.empty?

    @created.clear
    FileUtils.remove_entry(@directory) if @directory && File.directory?(@directory)
    observations[:resources_absent] = true
    verify_port_absent if @port
  end

  def verify_physical!
    verify_container
    actual = sql('SELECT VERSION(), @@server_uuid, @@hostname;').strip.split("\t")
    expected = ['8.4.11', receipt.fetch('server_uuid'), receipt.fetch('server_hostname')]
    raise 'Physical MySQL identity changed' unless actual == expected
  end

  private

  def remove_owned_resource(kind, identity)
    verify_resource!(kind, identity)
    docker(*removal(kind, identity))
    _, error, status = Open3.capture3(@docker, *inspection(kind, identity))
    raise 'Resource absence unproved' unless !status.success? && error.match?(/No such|not found/i)

    nil
  rescue StandardError => error
    error.class.name
  end

  def verify_port_absent
    socket = TCPSocket.new('127.0.0.1', @port)
    socket.close
    raise 'Owned loopback port is still reachable'
  rescue Errno::ECONNREFUSED
    observations[:loopback_port_refused] = true
  end

  def create_application_databases
    @application_user = "owned77_#{@token}"
    @application_password = SecureRandom.hex(24)
    @databases = %w[test queue_test cache_test cable_test].map { |suffix| "owned77_#{@token}_app_#{suffix}" }
    existing = sql('SHOW DATABASES;').lines.map(&:strip)
    raise 'Owned schemas already exist' if @databases.intersect?(existing)

    sql("CREATE USER '#{@application_user}'@'%' IDENTIFIED BY '#{@application_password}';")
    @databases.each do |database|
      sql("CREATE DATABASE `#{database}` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci; GRANT ALL ON `#{database}`.* TO '#{@application_user}'@'%';")
    end
  end

  def write_receipt(physical)
    @receipt = { 'token' => @token, 'test_run_id' => @labels.fetch('test.run_id'), 'work_item' => @labels.fetch('lisa.work_item'),
                 'namespace_prefix' => "owned77_#{@token}", 'container_id' => @container_id, 'network_name' => @name,
                 'volume_name' => @name, 'host_port' => @port, 'image_id' => @image_id, 'docker_executable' => @docker,
                 'server_uuid' => physical.fetch(1), 'server_hostname' => physical.fetch(2) }
    @directory = Dir.mktmpdir('owned77-test-')
    File.chmod(0o700, @directory)
    @receipt_path = File.join(@directory, 'ownership.json')
    File.write(@receipt_path, JSON.generate(receipt), mode: 'wx', perm: 0o600)
    observations[:physical_identity] = physical
    observations[:receipt_created] = true
    observations[:ownership] = receipt
  end

  def verify_image
    image = JSON.parse(docker('image', 'inspect', IMAGE)).fetch(0)
    @image_id = image.fetch('Id')
    observations[:image] = image.slice('Id', 'Architecture', 'Os', 'RepoDigests')
    raise 'MySQL immutable image mismatch' unless image.fetch('RepoDigests').include?(IMAGE.sub('mysql:8.4.11', 'mysql'))
  end

  def find_docker
    candidates = ENV.fetch('PATH').split(File::PATH_SEPARATOR).map { |path| File.join(path, 'docker') }
    candidates.push('/usr/local/bin/docker', '/opt/homebrew/bin/docker')
    candidates.find { |path| File.file?(path) && File.executable?(path) } || raise('Docker executable required')
  end

  def docker(*args, input: nil)
    output, _, status = Open3.capture3(@docker, *args, stdin_data: input)
    raise "Owned Docker operation failed: #{args.first}" unless status.success?

    output
  end

  def label_arguments
    @labels.flat_map { |key, value| ['--label', "#{key}=#{value}"] }
  end

  def create_resources
    docker('network', 'create', *label_arguments, @name)
    @created << ['network', @name]
    docker('volume', 'create', *label_arguments, @name)
    @created << ['volume', @name]
    @container_id = docker('run', '--pull=never', '-d', '--name', @name, *label_arguments, '--network', @name,
                           '--publish', '127.0.0.1::3306', '--mount', "type=volume,src=#{@name},dst=/var/lib/mysql",
                           '--env', 'MYSQL_ALLOW_EMPTY_PASSWORD=yes', IMAGE).strip
    @created << ['container', @container_id]
  end

  def inspection(kind, identity)
    [kind, 'inspect', identity]
  end

  def removal(kind, identity)
    kind == 'container' ? [kind, 'rm', '-f', identity] : [kind, 'rm', identity]
  end

  def verify_resource!(kind, identity)
    data = JSON.parse(docker(*inspection(kind, identity))).fetch(0)
    labels = kind == 'container' ? data.fetch('Config').fetch('Labels') : data.fetch('Labels')
    raise 'Foreign resource ownership refused' unless labels.slice(*@labels.keys) == @labels

    data
  end

  def verify_container
    data = verify_resource!('container', @container_id)
    raise 'Container identity mismatch' unless data.fetch('Id') == @container_id && data.fetch('Image') == @image_id && data.dig('State', 'Running')
    raise 'Container network mismatch' unless data.dig('NetworkSettings', 'Networks').keys == [@name]

    verify_endpoint(data)
    verify_resource!('network', @name)
    verify_resource!('volume', @name)
    verify_exclusive_resources
    data
  end

  def verify_exclusive_resources
    consumers = docker('ps', '-a', '--filter', "volume=#{@name}", '--format', '{{.ID}}').split
    raise 'Owned volume has foreign consumers' unless consumers == [@container_id[0, 12]]

    network = JSON.parse(docker('network', 'inspect', @name)).fetch(0)
    raise 'Owned network has foreign consumers' unless network.fetch('Containers').keys == [@container_id]
  end

  def verify_endpoint(data)
    ports = data.dig('NetworkSettings', 'Ports', '3306/tcp')
    raise 'Loopback-only port required' unless ports&.length == 1 && ports.first.fetch('HostIp') == '127.0.0.1'
    raise 'Loopback port changed' if @port && ports.first.fetch('HostPort').to_i != @port
    raise 'Owned volume mismatch' unless data.fetch('Mounts').one? { |mount| mount['Name'] == @name && mount['Destination'] == '/var/lib/mysql' }
  end

  def sql(statement)
    docker('exec', '-i', @container_id, 'mysql', '--protocol=TCP', '-h127.0.0.1', '-uroot', '-N', '-B', input: statement)
  end

  def wait_for_server
    120.times do
      output, _, status = Open3.capture3(@docker, 'exec', @container_id, 'mysql', '--protocol=TCP', '-h127.0.0.1', '-uroot', '-N', '-B',
                                         '-e', 'SELECT VERSION(), @@server_uuid, @@hostname;')
      if status.success?
        actual = output.strip.split("\t")
        raise 'Exact MySQL 8.4.11 required' unless actual.first == '8.4.11'
        raise 'Disposable server is not fresh' unless sql('SHOW DATABASES;').lines.map(&:strip).sort == %w[information_schema mysql performance_schema sys]

        return actual
      end
      sleep 0.5
    end
    raise 'Owned MySQL readiness failed'
  end
end

# Evaluate only the native declaration, before application boot or sockets.
module OwnedMigrationPreaccess
  CONNECTION_SCRIPT = <<~CODE
    require 'mysql2'; require 'json'; require 'active_record'; require 'active_record/database_configurations'; require 'active_support/configuration_file'
    owner = JSON.parse(ARGV.fetch(0))
    raw = ActiveSupport::ConfigurationFile.parse('config/database.yml')
    configs = ActiveRecord::DatabaseConfigurations.new(raw)
    roles = configs.configs_for(env_name: 'test', include_hidden: true)
    results = roles.map do |role|
      client = Mysql2::Client.new(role.configuration_hash)
      begin
        actual = client.query('SELECT DATABASE() AS db, CURRENT_USER() AS user, VERSION() AS version, @@server_uuid AS uuid, @@hostname AS hostname').first
        expected = { 'db' => role.database, 'user' => ENV.fetch('DATABASE_USER') + '@%', 'version' => '8.4.11', 'uuid' => owner.fetch('server_uuid'), 'hostname' => owner.fetch('server_hostname') }
        raise 'Physical application role mismatch' unless actual == expected
        raise 'Application schema not empty' unless client.query('SHOW TABLES').none?
        grants = client.query('SHOW GRANTS').map(&:values).flatten
        names = %w[test queue_test cache_test cable_test].map { |suffix| ENV.fetch('DATABASE_NAME') + '_' + suffix }
        raise 'Application grants not bounded' unless grants.size == 5 && grants.count { |grant| grant.include?('USAGE ON *.*') } == 1 && names.all? { |name| grants.one? { |grant| grant.include?('`' + name + '`.*') } }
        { role: role.name, identity: actual, empty: true, bounded_grants: true }
      ensure
        client.close
      end
    end
    puts JSON.generate(results)
  CODE

  def self.verify_connections!(env, receipt)
    output, _, status = Open3.capture3(env, RbConfig.ruby, '-e', CONNECTION_SCRIPT, JSON.generate(receipt), chdir: OwnedMigrationMysql::ROOT, unsetenv_others: true)
    raise 'Actual application role identity failed' unless status.success?

    JSON.parse(output)
  end

  def self.validate!(env)
    script = <<~'CODE'
      require 'active_record'; require 'active_record/database_configurations'; require 'active_support/configuration_file'
      path = File.expand_path('spec/rails_helper.rb'); declaration, boundary = File.read(path).split("LisaTestIsolation.environment!\n", 2)
      raise 'Native isolation declaration missing' unless boundary && declaration.include?('module LisaTestIsolation')
      eval(declaration, TOPLEVEL_BINDING, path)
      LisaTestIsolation.environment!; LisaTestIsolation.preflight!
      raw = ActiveSupport::ConfigurationFile.parse('config/database.yml'); shared = raw.delete('shared')
      configs = ActiveRecord::DatabaseConfigurations.new(LisaTestIsolation.merge_shared!(raw, shared))
      LisaTestIsolation.databases!(configs)
      roles = configs.configs_for(env_name: 'test', include_hidden: true)
      raise 'Role inventory mismatch' unless roles.map(&:name).sort == %w[primary primary_replica queue cache cable].sort
      roles.each do |role|
        c = role.configuration_hash
        suffix = %w[primary primary_replica].include?(role.name) ? '_test' : "_#{role.name}_test"
        raise 'Owned role mismatch' unless role.database == ENV.fetch('DATABASE_NAME') + suffix && c[:host] == '127.0.0.1' && c[:port].to_i == ENV.fetch('DATABASE_PORT').to_i && c[:username] == ENV.fetch('DATABASE_USER') && !c[:url] && !c[:socket] && !c[:aws_rds_iam_auth]
      end
    CODE
    _, _, status = Open3.capture3(env, RbConfig.ruby, '-e', script, chdir: OwnedMigrationMysql::ROOT, unsetenv_others: true)
    raise 'Native environment/preaccess failed' unless status.success?

    :verified
  end
end

# Optional tracked CLI caller: provision all four empty app schemas, load their
# existing schema declarations, then run the ordinary unfiltered RSpec command.
# Guard only the actual terminal HTTP handler; SDK stub handlers remain intact.
module OwnedMigrationAwsObserver
  class Blocked < StandardError; end

  def self.install!
    # Child test harnesses may scrub AWS variables before Ruby's preload.
    ENV['AWS_EC2_METADATA_DISABLED'] = 'true'

    require 'aws-sdk-ssm'
    state = { observer: 'Seahorse::Client::NetHttp::Handler#call', metadata_lookup_disabled: ENV['AWS_EC2_METADATA_DISABLED'] == 'true', control_interceptions: 0,
              observed_transport_attempts: 0, phase: :control }
    guard = Module.new do
      define_method(:call) do |context|
        if state[:phase] == :control
          state[:control_interceptions] += 1
          state[:control_request] = OwnedMigrationAwsObserver.request_record(context)
        else
          state[:observed_transport_attempts] += 1
        end
        raise Blocked, 'expected77'
      end
    end
    Seahorse::Client::NetHttp::Handler.prepend(guard)
    nonstub_control!(state)
    stub_control!(state)
    state[:phase] = :observed
    at_exit { warn "OWNED77_AWS=#{JSON.generate(state.except(:phase))}" }
  end

  def self.client(stubbed)
    Aws::SSM::Client.new(region: 'us-east-1', credentials: Aws::Credentials.new('owned77-synthetic', 'owned77-synthetic'),
                         stub_responses: stubbed, retry_mode: 'standard', max_attempts: 1, retry_limit: 0)
  end

  def self.request_record(context)
    body = context.http_request.body
    serialized = JSON.parse(body.read)
    body.rewind
    { operation: context.operation_name.to_s, body: serialized }
  end

  def self.nonstub_control!(state)
    client(false).get_parameters_by_path(path: '/owned77/control/', recursive: true)
    raise 'Real terminal SDK reaching control missing'
  rescue Blocked => error
    expected = { operation: 'get_parameters_by_path', body: { 'Path' => '/owned77/control/', 'Recursive' => true } }
    raise 'Terminal SDK reaching control mismatch' unless error.message == 'expected77' && state[:control_interceptions] == 1 && state[:control_request] == expected
  end

  def self.stub_control!(state)
    state[:phase] = :stub
    sdk = client(true)
    sdk.stub_responses(:get_parameters_by_path, parameters: [{ name: '/owned77/stub/value', type: 'String', value: 'owned77-synthetic-response' }])
    response = sdk.get_parameters_by_path(path: '/owned77/stub/', recursive: true)
    actual = request_record(response.context)
    actual[:response] = response.parameters.map { |parameter| { name: parameter.name, value: parameter.value } }
    actual[:terminal_interceptions] = state[:observed_transport_attempts]
    expected = { operation: 'get_parameters_by_path', body: { 'Path' => '/owned77/stub/', 'Recursive' => true },
                 response: [{ name: '/owned77/stub/value', value: 'owned77-synthetic-response' }], terminal_interceptions: 0 }
    raise 'Actual SDK stub pipeline control mismatch' unless actual == expected && sdk.api_requests.one? && sdk.api_requests.first[:operation_name] == :get_parameters_by_path

    state[:stub_control] = actual
  end
end

module OwnedMigrationSuite
  def self.observe_aws!
    OwnedMigrationAwsObserver.install!
  end

  def self.load_application_schemas(env)
    schema_script = <<~'CODE'
      require_relative 'config/environment'
      configs = ActiveRecord::Base.configurations.configs_for(env_name: 'test', include_hidden: true)
      configs.reject(&:replica?).each do |config|
        tasks = ActiveRecord::Tasks::DatabaseTasks
        file = config.name == 'primary' ? 'db/schema.rb' : "db/#{config.name}_schema.rb"
        tasks.send(:with_temporary_pool, config) do |pool|
          pool.with_connection do |connection|
            raise 'Owned schema not empty' unless connection.tables.empty?
            raise 'Actual database mismatch' unless connection.select_value('SELECT DATABASE()') == config.database
          end
          tasks.load_schema(config, :ruby, file)
        end
      end
    CODE
    raise 'Owned schema load failed' unless system(env, RbConfig.ruby, '-e', schema_script, chdir: OwnedMigrationMysql::ROOT, unsetenv_others: true)
  end

  def self.run
    raise 'Usage: ruby spec/fixtures/migrations/owned_mysql.rb rspec' unless ARGV == ['rspec']

    server = OwnedMigrationMysql.new
    begin
      server.start
      env = server.prepare_application.merge('MIGRATION_PROBE_OWNERSHIP' => server.receipt_path, 'OWNED77_AWS_OBSERVER' => '1')
      observer = "-r#{File.expand_path(__FILE__)}"
      env['RUBYOPT'] = [env['RUBYOPT'], observer].compact.join(' ')
      load_application_schemas(env)

      server.verify_physical!
      system(env, 'bundle', 'exec', 'rspec', chdir: OwnedMigrationMysql::ROOT, unsetenv_others: true)
      status = $?
      code = status.exitstatus || 1
    ensure
      server.close
      warn "OWNED77_SUITE=#{JSON.generate(server.observations)}"
    end
    code
  end
end

OwnedMigrationSuite.observe_aws! if ENV['OWNED77_AWS_OBSERVER'] == '1'
exit OwnedMigrationSuite.run if $0 == __FILE__
