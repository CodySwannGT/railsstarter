# frozen_string_literal: true

require_relative '../browser/request_security_harness'
require 'open3'
require 'digest'
require 'shellwords'

# Every command is a captured direct child with a monotonic deadline.
class RateLimitCommand
  def initialize(directory)
    @directory = directory
    @receipts = []
  end

  attr_reader :receipts

  def start(arguments, environment = {})
    log = File.join(@directory, "command-#{SecureRandom.hex(8)}.log")
    pid = Process.spawn(environment, *arguments, pgroup: true, out: [log, 'wx', 0o600], err: [:child, :out])
    { arguments: arguments, log: log, process: RequestSecurityProcess.new(pid, child: true), result: environment['REQUEST_RATE_RESULT'] }
  end

  def finish(item, timeout: 45)
    process = item.fetch(:process)
    complete = RequestSecurityDeadline.wait(timeout) { process.exited? }
    status = process.status
    process.terminate(timeout: 2) unless complete
    output = File.read(item.fetch(:log))
    @receipts << { command: item[:arguments], identity: process.identity, exit: status&.exitstatus, complete: complete, signals: process.signals, absent: process.absent? }
    raise "Owned command timed out: #{item[:arguments].first}" unless complete
    raise "Owned command failed: #{output}" unless status&.success?

    output
  end

  def run(arguments, environment = {}, timeout: 45)
    finish(start(arguments, environment), timeout: timeout)
  end
end

# Fresh labeled Docker/MySQL ownership is established before any adapter access.
class RateLimitDatabase
  IMAGE = 'mysql:8.4.11@sha256:6ea90827b1100f8f2ae306a539f86d2c264a26ed435a2a9f75551dd5c3aeb242'

  def initialize(directory, token)
    @command = RateLimitCommand.new(directory)
    @state = { token: token, container: "request-limit-#{token}", volume: "request-limit-#{token}",
               root_password: SecureRandom.hex(24), password: SecureRandom.hex(24), user: "quota_#{token[0, 12]}",
               base: "railsstarter_63_smoke_c78_#{token[0, 8]}" }
    @state[:schemas] = %w[test queue_test cache_test cable_test].map { |suffix| "#{@state[:base]}_#{suffix}" }
  end

  def start
    discover_docker
    docker('volume', 'create', '--label', "request-limit.owner=#{@state[:token]}", @state[:volume])
    @state[:volume_created] = true
    create_container
    validate!
    @state[:port] = JSON.parse(docker('inspect', '--format', '{{json .NetworkSettings.Ports}}', @state[:id])).fetch('3306/tcp').first.fetch('HostPort').to_i
    raise 'Unsafe owned MySQL port' unless @state[:port].between?(1025, 65_535) && @state[:port] != 3306

    wait_for_database
    create_schemas
  end

  def create_container
    @state[:id] = docker('run', '-d', '--name', @state[:container], '--label', "request-limit.owner=#{@state[:token]}",
                         '--mount', "type=volume,source=#{@state[:volume]},target=/var/lib/mysql", '-p', '127.0.0.1::3306',
                         '-e', 'MYSQL_ROOT_PASSWORD', '-e', 'MYSQL_ROOT_HOST', IMAGE,
                         environment: { 'MYSQL_ROOT_PASSWORD' => @state[:root_password], 'MYSQL_ROOT_HOST' => '%' }).strip
  end

  def discover_docker
    @binary = if ENV['DOCKER_BIN']
                RequestSecurityExecutable.verified(ENV['DOCKER_BIN'], 'DOCKER_BIN')
              else
                RequestSecurityExecutable.paths(ENV, ['docker']).find do |p|
                  RequestSecurityExecutable.executable?(p)
                end
              end
    raise 'Missing Docker executable; provide DOCKER_BIN or docker on PATH' unless @binary

    @endpoint = ENV['DOCKER_HOST'] || @command.run([@binary, 'context', 'inspect', '--format', '{{.Endpoints.docker.Host}}']).strip
    raise 'Owned MySQL requires a local Docker Unix socket' unless @endpoint&.start_with?('unix://') && File.socket?(@endpoint.delete_prefix('unix://'))
  end

  def docker(*arguments, environment: {})
    @command.run([@binary, '--host', @endpoint, *arguments], environment)
  end

  def validate!
    fields = '{"Id":{{json .Id}},"Config":{"Labels":{{json .Config.Labels}}},"Mounts":{{json .Mounts}},"NetworkSettings":{"Ports":{{json .NetworkSettings.Ports}}}}'
    observed = JSON.parse(docker('inspect', '--format', fields, @state[:id]))
    safe = observed['Id'] == @state[:id] && observed.dig('Config', 'Labels', 'request-limit.owner') == @state[:token] &&
           observed['Mounts'].any? { |mount| mount['Name'] == @state[:volume] && mount['Destination'] == '/var/lib/mysql' } &&
           observed.dig('NetworkSettings', 'Ports', '3306/tcp').all? { |port| port['HostIp'] == '127.0.0.1' }
    raise 'MySQL container ownership mismatch' unless safe
  end

  def admin
    validate!
    require 'mysql2'
    Mysql2::Client.new(host: '127.0.0.1', port: @state.fetch(:port), username: 'root', password: @state[:root_password], connect_timeout: 2, read_timeout: 5)
  end

  def wait_for_database
    require 'mysql2'
    ready = RequestSecurityDeadline.wait(40) do
      connection = admin
      raise 'Pinned MySQL version mismatch' unless connection.query('SELECT VERSION() AS version').first.fetch('version').start_with?('8.4.11')

      connection.close
      true
    rescue Mysql2::Error
      false
    end
    raise 'Owned MySQL did not become ready' unless ready
  end

  def create_schemas
    connection = admin
    @state[:schemas].each do |schema|
      raise 'Invalid fresh schema namespace' unless schema.match?(/\Arailsstarter_63_smoke_c78_[a-f0-9]{8}_(?:test|queue_test|cache_test|cable_test)\z/)

      connection.query("CREATE DATABASE `#{schema}` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci")
    end
    connection.query("CREATE USER '#{@state[:user]}'@'%' IDENTIFIED BY '#{@state[:password]}'")
    @state[:schemas].each { |schema| connection.query("GRANT ALL ON `#{schema}`.* TO '#{@state[:user]}'@'%'") }
  ensure
    connection&.close
  end

  def environment
    { 'PRIMARY_DB_HOST' => '127.0.0.1', 'DATABASE_REPLICA_HOST' => '127.0.0.1', 'DATABASE_PORT' => @state.fetch(:port).to_s,
      'DATABASE_NAME' => @state[:base], 'DATABASE_USER' => @state[:user], 'DATABASE_PASSWORD' => @state[:password],
      'DATABASE_IAM_AUTH' => 'false', 'DATABASE_SSL' => 'false' }
  end

  def inventory
    @state.slice(:token, :container, :id, :volume, :port, :base, :schemas, :user).merge(endpoint: @endpoint, image: IMAGE,
                                                                                        password_sha256: Digest::SHA256.hexdigest(@state[:password]))
  end

  def stop
    return unless @state[:volume_created]
    return verify_absence if @cleanup

    validate! if @state[:id]
    volume = JSON.parse(docker('volume', 'inspect', @state[:volume])).first
    raise 'Volume ownership mismatch' unless volume.dig('Labels', 'request-limit.owner') == @state[:token]

    docker('rm', '-f', @state[:id]) if @state[:id]
    docker('volume', 'rm', @state[:volume])
    verify_absence
  end

  def verify_absence
    raise 'Owned MySQL remains' if @state[:id] && docker('ps', '-aq', '--filter', "id=#{@state[:id]}").strip != ''
    raise 'Owned volume remains' if docker('volume', 'ls', '-q', '--filter', "name=^#{@state[:volume]}$").strip != ''

    @cleanup = { container_absent: true, volume_absent: true, port_closed: !@state[:port] || port_closed? }
    raise 'Owned MySQL port remains' unless @cleanup[:port_closed]
  end

  attr_reader :cleanup

  def port_closed?
    socket = Socket.tcp('127.0.0.1', @state[:port], connect_timeout: 1)
    socket.close
    false
  rescue Errno::ECONNREFUSED
    true
  end
end

# Two separately booted processes synchronize only their start, never their counters.
class RateLimitConcurrency
  def initialize(harness, command)
    @harness = harness
    @command = command
  end

  def run(key, isolation)
    barrier = "barrier-#{SecureRandom.hex(8)}"
    extra = { 'REQUEST_RATE_KEY' => key, 'REQUEST_RATE_ISOLATION' => isolation, 'REQUEST_RATE_OPERATIONS' => '4', 'REQUEST_RATE_BARRIER' => barrier }
    children = Array.new(2) { @harness.start_command(@command, 'increment', extra) }
    ready = RequestSecurityDeadline.wait(30) { Dir.glob(File.join(@harness.scratch, "#{barrier}-*")).length == 2 }
    raise 'Two independent counter processes did not reach barrier' unless ready

    File.write(File.join(@harness.scratch, barrier), @harness.token, mode: 'wx', perm: 0o600)
    children.map do |child|
      @command.finish(child)
      @harness.result(child)
    end
  ensure
    children&.each { |child| child.fetch(:process).terminate(timeout: 2) }
  end
end

# Public source-identical snapshot fixture; never prepares or resets ambient schemas.
class RequestRateLimitHarness
  DOT_ENTRIES = %w[. ..].freeze
  attr_reader :root, :scratch, :token, :database, :processes, :observations

  def initialize
    @root = File.expand_path('../../..', __dir__)
    @scratch = Dir.mktmpdir('request-rate-limit-')
    File.chmod(0o700, @scratch)
    @token = SecureRandom.hex(12)
    @database = RateLimitDatabase.new(@scratch, @token)
    @command = RateLimitCommand.new(@scratch)
    @processes = []
    @observations = []
    File.write(File.join(@scratch, 'owner.json'), JSON.generate(token: @token), mode: 'wx', perm: 0o600)
  end

  def start
    snapshot
    @database.start
    write_owner
    result = command('prepare')
    @observations << result
    self
  end

  def snapshot
    @snapshot = File.join(@scratch, 'source')
    FileUtils.mkdir(@snapshot, mode: 0o700)
    %w[app config lib db bin public Gemfile Gemfile.lock Gemfile.lisa config.ru Rakefile VERSION].each { |name| FileUtils.cp_r(File.join(@root, name), @snapshot) }
    FileUtils.mkdir_p([File.join(@snapshot, 'spec/fixtures'), File.join(@snapshot, 'log'), File.join(@snapshot, 'tmp')])
    FileUtils.cp_r(File.join(@root, 'spec/fixtures/runtime'), File.join(@snapshot, 'spec/fixtures'))
    Dir.glob(File.join(@snapshot, '**/*'), File::FNM_DOTMATCH).each do |path|
      next if DOT_ENTRIES.include?(File.basename(path))

      File.chmod(File.directory?(path) ? 0o700 : 0o600, path)
    end
  end

  def write_owner
    File.write(File.join(@scratch, 'database-owner.json'), JSON.generate(@database.inventory.merge(root: @snapshot)), mode: 'wx', perm: 0o600)
  end

  def environment(extra = {})
    scrub = ENV.to_h.select { |key, _| key.match?(/\A(?:AWS_|OTEL_|DATABASE|PRIMARY_DB_|SECRET_KEY_BASE|ALLOWED_HOSTS|REQUEST_RATE_|REQUEST_INGRESS_|ALB_TRUSTED_|THRUSTER_)|_DATABASE_URL\z/) }
    scrub.transform_values { nil }.merge(@database.environment).merge(
      'RAILS_ENV' => 'test', 'RACK_ENV' => 'test', 'RUNTIME_SMOKE_DB' => '1', 'RUNTIME_SMOKE_IMAGE' => '0',
      'REQUEST_RATE_ROOT' => @snapshot, 'REQUEST_RATE_SCRATCH' => @scratch, 'REQUEST_RATE_TOKEN' => @token,
      'REQUEST_RATE_LIMIT' => '12', 'REQUEST_RATE_PERIOD' => '600', 'REQUEST_INGRESS_PROFILE' => 'direct'
    ).merge(extra)
  end

  def command(mode, extra = {})
    item = start_command(@command, mode, extra)
    @command.finish(item)
    record = result(item)
    @observations << { command: mode, result: record }
    record
  end

  def arguments(mode)
    [RbConfig.ruby, File.join(__dir__, 'request_rate_limit_server.rb'), mode]
  end

  def start_command(command, mode, extra)
    result = File.join(@scratch, "result-#{SecureRandom.hex(8)}.json")
    command.start(arguments(mode), environment(extra.merge('REQUEST_RATE_RESULT' => result)))
  end

  def result(item)
    JSON.parse(File.read(item.fetch(:result)))
  end

  def concurrent(key, isolation)
    results = RateLimitConcurrency.new(self, @command).run(key, isolation)
    @observations << { key: key, isolation: isolation, concurrent: results }
    results
  end

  def spawn_server(extra = {})
    port = free_port
    log = File.join(@scratch, "server-#{port}.log")
    pid = Process.spawn(environment(extra.merge('REQUEST_RATE_PORT' => port.to_s)), RbConfig.ruby,
                        File.join(__dir__, 'request_rate_limit_server.rb'), 'server', pgroup: true, out: [log, 'wx', 0o600], err: [:child, :out])
    process = RequestSecurityProcess.new(pid, child: true)
    @processes << { process: process, port: port, log: log, role: 'Rails' }
    ready = RequestSecurityDeadline.wait(30) do
      response(port, '/up').code == '200'
    rescue Errno::ECONNREFUSED
      raise File.read(log) if process.exited?

      false
    end
    raise 'Owned Rails did not become ready' unless ready

    port
  end

  def spawn_alb(target)
    spawn_transport('alb', arguments('alb'), environment('REQUEST_RATE_TARGET_PORT' => target.to_s), host: '::1')
  end

  def spawn_thruster(settings)
    target = free_port
    executable = Gem.bin_path('thruster', 'thrust')
    extra = environment(settings.merge('REQUEST_RATE_PORT' => target.to_s, 'THRUSTER_TARGET_PORT' => target.to_s,
                                       'THRUSTER_FORWARD_HEADERS' => 'true', 'THRUSTER_HTTPS_PORT' => '0'))
    front = spawn_transport('Thruster', [RbConfig.ruby, executable, *arguments('server')], extra)
    parent = @processes.last.fetch(:process)
    capture_upstream(parent, target)
    [front, target]
  end

  def capture_upstream(parent, target)
    children = IO.popen(['ps', '-axo', 'pid=,ppid=,command=']).read.lines.select do |line|
      line.split[1] == parent.pid.to_s && line.include?(File.join(__dir__, 'request_rate_limit_server.rb'))
    end
    raise 'Thruster real upstream identity ambiguous' unless children.one?

    upstream = RequestSecurityProcess.new(children.first.split.first.to_i)
    @processes << { process: upstream, port: target, role: 'Thruster upstream Rails' }
  end

  def spawn_transport(role, arguments, extra, host: '127.0.0.1')
    port = free_port
    extra = extra.merge(role == 'alb' ? { 'REQUEST_RATE_PORT' => port.to_s } : { 'THRUSTER_HTTP_PORT' => port.to_s })
    log = File.join(@scratch, "#{role}-#{port}.log")
    pid = Process.spawn(extra, *arguments, pgroup: true, out: [log, 'wx', 0o600], err: [:child, :out])
    process = RequestSecurityProcess.new(pid, child: true)
    @processes << { process: process, port: port, log: log, role: role, host: host }
    ready = RequestSecurityDeadline.wait(30) do
      response(port, '/up', {}, host: host).code == '200'
    rescue Errno::ECONNREFUSED
      raise File.read(log) if process.exited?

      false
    end
    raise "Owned #{role} did not become ready" unless ready

    port
  end

  def free_port
    socket = TCPServer.new('127.0.0.1', 0)
    socket.addr[1]
  ensure
    socket&.close
  end

  def response(port, path = '/__quota', headers = {}, local_host: nil, host: '127.0.0.1')
    http = Net::HTTP.new(host, port)
    http.local_host = local_host if local_host
    http.open_timeout = 2
    http.read_timeout = 5
    response = http.start { |session| session.get(path, headers) }
    @observations << { http: { port: port, path: path, host: host, input_headers: headers, status: response.code, headers: response.to_hash, body: response.body } }
    response
  end

  def stop
    errors = []
    stop_processes(errors)
    begin
      @database.stop
    rescue StandardError => error
      errors << error.message
    end
    persist(errors)
    raise errors.join('; ') unless errors.empty?

    raise 'Unsafe scratch identity' if File.symlink?(@scratch) || JSON.parse(File.read(File.join(@scratch, 'owner.json')))['token'] != @token

    FileUtils.remove_entry_secure(@scratch)
    raise 'Owned scratch remains' if File.exist?(@scratch)

    persist_absence
  end

  def stop_processes(errors)
    @processes.reverse_each do |item|
      item[:process].terminate(timeout: 3)
      raise 'Owned listener remains' unless closed_port?(item[:port], item.fetch(:host, '127.0.0.1'))
    rescue StandardError => error
      errors << error.message
    end
  end

  def persist_absence
    directory = ENV.fetch('REQUEST_RATE_ARTIFACT_DIR', nil)
    return unless directory

    File.write(File.join(directory, "quota-#{@token}-absence.json"), JSON.generate(scratch: @scratch, absent: !File.exist?(@scratch)), mode: 'wx', perm: 0o600)
  end

  def closed_port?(port, host = '127.0.0.1')
    socket = Socket.tcp(host, port, connect_timeout: 1)
    socket.close
    false
  rescue Errno::ECONNREFUSED
    true
  end

  def persist(errors)
    directory = ENV.fetch('REQUEST_RATE_ARTIFACT_DIR', nil)
    return unless directory

    record = { token: @token, database: @database.inventory, database_cleanup: @database.cleanup, scratch: @scratch,
               commands: @command.receipts, observations: @observations, errors: errors,
               processes: process_receipts }
    File.write(File.join(directory, "quota-#{@token}.json"), JSON.pretty_generate(record), mode: 'wx', perm: 0o600)
    Dir.glob(File.join(@scratch, '*.{log,jsonl}')).each { |file| FileUtils.cp(file, File.join(directory, "#{@token}-#{File.basename(file)}")) }
  end

  def process_receipts
    @processes.map do |item|
      process = item.fetch(:process)
      { role: item[:role], identity: process.identity, signals: process.signals, absent: process.absent?,
        port: item[:port], closed: closed_port?(item[:port], item.fetch(:host, '127.0.0.1')) }
    end
  end
end
