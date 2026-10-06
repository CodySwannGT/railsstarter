# frozen_string_literal: true

require 'bundler/setup'
require 'json'
require 'digest'
require 'fileutils'
require 'net/http'

# Validate the fixture's positively owned four-schema endpoint before Rails or SQL.
class RateLimitServerOwnership
  def self.validate!
    scratch = ENV.fetch('REQUEST_RATE_SCRATCH')
    token = ENV.fetch('REQUEST_RATE_TOKEN')
    owner = JSON.parse(File.read(File.join(scratch, 'database-owner.json')))
    root = ENV.fetch('REQUEST_RATE_ROOT')
    raise 'Invalid owned source snapshot' unless root == File.join(scratch, 'source') && !File.symlink?(scratch)
    raise 'Invalid fixture identity' unless owner.values_at('token', 'root') == [token, root] && token.match?(/\A[a-f0-9]{24}\z/)

    validate_endpoint(owner)
    owner
  end

  def self.validate_endpoint(owner)
    raise 'Invalid owned endpoint' unless ENV.values_at('PRIMARY_DB_HOST', 'DATABASE_REPLICA_HOST', 'DATABASE_PORT') == ['127.0.0.1', '127.0.0.1', owner.fetch('port').to_s]
    raise 'Invalid owned schema/user' unless ENV.values_at('DATABASE_NAME', 'DATABASE_USER') == owner.values_at('base', 'user')
    raise 'Invalid fixture credential' unless Digest::SHA256.hexdigest(ENV.fetch('DATABASE_PASSWORD')) == owner.fetch('password_sha256')
  end

  def self.boot
    owner = validate!
    root = owner.fetch('root')
    require File.join(root, 'spec/fixtures/runtime/smoke')
    DependencySmoke.validate_environment!
    DependencySmoke.configure_environment
    DependencySmoke.configure_aws
    require File.join(root, 'config/environment')
    validate_roles(owner)
    DependencySmoke.validate_authored_responses!
  end

  def self.validate_roles(owner)
    configs = ActiveRecord::Base.configurations.configs_for(env_name: 'test', include_hidden: true)
    raise 'Unexpected schema roles' unless configs.map(&:name).sort == %w[cache cable primary primary_replica queue].sort
    raise 'Foreign database config' unless configs.all? do |config|
      owner.fetch('schemas').include?(config.database) && config.host == '127.0.0.1' && config.configuration_hash.fetch(:port).to_i == owner.fetch('port')
    end
  end
end

# All DDL is native Rails in the owned source snapshot after public smoke guards.
class RateLimitSchemaCommands
  def self.prepare
    databases = DependencySmoke.load_schemas
    migrate('db:migrate:cache')
    { databases: databases, schema: Rails.root.join('db/cache_schema.rb').read, audit: RateLimitCounterCommands.audit }
  end

  def self.migrate(task)
    Rails.application.load_tasks
    ENV['VERSION'] = '20261005000000' if task.include?('down')
    Rake::Task[task].invoke
  end

  def self.down
    migrate('db:migrate:down:cache')
    { counter_table: CacheRecord.connection_pool.with_connection { |connection| connection.table_exists?('request_rate_limit_counters') } }
  end

  def self.up
    migrate('db:migrate:cache')
    RateLimitCounterCommands.audit
  end
end

# Real independent process counters, never a mocked/cache-in-memory substitute.
class RateLimitCounterCommands
  def self.increment
    store = RequestRateLimitStore.new(namespace: 'test')
    key = ENV.fetch('REQUEST_RATE_KEY')
    counts = []
    isolation = ENV.fetch('REQUEST_RATE_ISOLATION', 'read_committed').to_sym
    raise 'Unknown test isolation' unless %i[read_committed repeatable_read].include?(isolation)

    CacheRecord.connection_pool.with_connection do |connection|
      connection.execute("SET SESSION TRANSACTION ISOLATION LEVEL #{isolation.to_s.upcase.tr('_', ' ')}")
    end
    wait_at_barrier
    Integer(ENV.fetch('REQUEST_RATE_OPERATIONS', '1')).times do
      counts << store.increment(key, 1, expires_in: 600)
      sleep 0.01
    end
    { pid: Process.pid, isolation: isolation, counts: counts, key: store.digest_key(key), audit: audit }
  end

  def self.wait_at_barrier
    return unless ENV['REQUEST_RATE_BARRIER']

    path = File.join(ENV.fetch('REQUEST_RATE_SCRATCH'), ENV.fetch('REQUEST_RATE_BARRIER'))
    raise 'Unsafe barrier path' unless ENV.fetch('REQUEST_RATE_BARRIER').match?(/\Abarrier-[a-f0-9]+\z/)

    File.write("#{path}-#{Process.pid}", Process.pid.to_s, mode: 'wx', perm: 0o600)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
    until File.file?(path)
      raise 'Owned counter barrier timeout' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.02
    end
  end

  def self.audit
    connection = CacheRecord.connection_pool
    cache = connection.with_connection do |adapter|
      { database: adapter.select_value('SELECT DATABASE()'), isolation: adapter.select_value('SELECT @@transaction_isolation'),
        columns: adapter.columns('request_rate_limit_counters').map(&:name), indexes: indexes(adapter) }
    end
    primary = ApplicationRecord.connection_pool.with_connection do |adapter|
      { database: adapter.select_value('SELECT DATABASE()'), counter_table: adapter.table_exists?('request_rate_limit_counters') }
    end
    { cache: cache, primary: primary, rows: RequestRateLimitCounter.order(:counter_key).map { |row| row.attributes.slice('counter_key', 'count', 'expires_at') } }
  end

  def self.indexes(adapter)
    adapter.indexes('request_rate_limit_counters').map { |index| { columns: index.columns, unique: index.unique } }
  end

  def self.expiration
    store = RequestRateLimitStore.new(namespace: 'test')
    name = ENV.fetch('REQUEST_RATE_KEY')
    store.increment(name, 1, expires_in: 2)
    key = store.digest_key(name)
    first = RequestRateLimitCounter.find_by!(counter_key: key).attributes.slice('count', 'expires_at')
    store.increment(name, 1, expires_in: 600)
    second = RequestRateLimitCounter.find_by!(counter_key: key).attributes.slice('count', 'expires_at')
    sleep 0.02 until Time.now.to_i >= first.fetch('expires_at')
    begin
      store.increment(name, 1, expires_in: 600)
    rescue RequestRateLimitStore::Unavailable => error
      failure = error.message
    end
    { first: first, second: second, failure: failure, expired_count: RequestRateLimitCounter.find_by!(counter_key: key).count }
  end

  def self.housekeeping
    store = RequestRateLimitStore.new(namespace: 'test')
    key = store.digest_key(ENV.fetch('REQUEST_RATE_KEY'))
    active = RequestRateLimitCounter.find_by!(counter_key: key)
    original = active.attributes.slice('count', 'expires_at')
    pressure = cache_pressure
    pruning = expired_batches
    { pressure: pressure, pruning: pruning, before: original, after: active.reload.attributes.slice('count', 'expires_at'), audit: audit }
  end

  def self.expired_batches
    timestamp = Time.current
    rows = Array.new(1001) do |number|
      { counter_key: Digest::SHA256.hexdigest("expired/#{ENV.fetch('REQUEST_RATE_TOKEN')}/#{number}"), count: 8,
        expires_at: timestamp.to_i - 1, created_at: timestamp, updated_at: timestamp }
    end
    RequestRateLimitCounter.create!(rows)
    first = PruneRequestRateLimitsJob.perform_now
    remaining = RequestRateLimitCounter.where(expires_at: ..Time.now.to_i).count
    second = PruneRequestRateLimitsJob.perform_now
    { first: first, remaining: remaining, second: second, expired_absent: RequestRateLimitCounter.where(expires_at: ..Time.now.to_i).none? }
  end

  def self.cache_pressure
    SolidCache::Record.connects_to(database: { writing: :cache })
    general_cache = SolidCache::Store.new
    10.times { |number| general_cache.write("pressure/#{number}", 'x' * 1024) }
    entries_before = SolidCache::Entry.count
    general_cache.clear
    { class: general_cache.class.name, entries_before: entries_before, entries_after: SolidCache::Entry.count }
  end
end

# Actual Puma/middleware transport endpoint; no alternate IP policy is used here.
class RateLimitHttpServer
  def self.run
    routes
    require 'puma'
    server = Puma::Server.new(observer)
    port = Integer(ENV.fetch('REQUEST_RATE_PORT'))
    server.add_tcp_listener('127.0.0.1', port)
    server.add_tcp_listener('::1', port)
    trap('TERM') { server.stop(true) }
    server.run.join
  end

  def self.routes
    Rails.application.routes.prepend do
      get '/__quota', to: lambda { |env|
        data = env.fetch('rack.attack.throttle_data', {}).fetch('anonymous/ip', {})
        result = { ip: env.fetch('request_policy.client_ip'), count: data[:count], pid: Process.pid,
                   middleware: Rails.application.middleware.map do |entry|
                     entry.klass.name
                   end, headers: env.slice('REMOTE_ADDR', 'HTTP_X_FORWARDED_FOR', 'HTTP_FORWARDED', 'HTTP_X_REAL_IP', 'HTTP_CLIENT_IP') }
        [200, { 'content-type' => 'application/json' }, [JSON.generate(result)]]
      }
    end
  end

  def self.observer
    lambda do |env|
      original = env.slice('REMOTE_ADDR', 'HTTP_X_FORWARDED_FOR', 'PATH_INFO')
      response = Rails.application.call(env)
      file = File.join(ENV.fetch('REQUEST_RATE_SCRATCH'), "socket-#{Process.pid}.jsonl")
      File.open(file, 'a', 0o600) { |stream| stream.write("#{JSON.generate(original: original, status: response.first, canonical: env['request_policy.client_ip'])}\n") }
      response
    end
  end
end

# Local append-mode ALB transport model; it is deliberately not live AWS evidence.
class RateLimitAlbModel
  def self.run
    target = Integer(ENV.fetch('REQUEST_RATE_TARGET_PORT'))
    app = ->(env) { forward(env, target) }
    server = Puma::Server.new(app)
    server.add_tcp_listener('::1', Integer(ENV.fetch('REQUEST_RATE_PORT')))
    trap('TERM') { server.stop(true) }
    server.run.join
  end

  def self.forward(env, target)
    http = Net::HTTP.new('::1', target)
    http.open_timeout = 2
    http.read_timeout = 5
    headers = forwarded_headers(env)
    headers['X-FORWARDED-FOR'] = [env['HTTP_X_FORWARDED_FOR'], env.fetch('REMOTE_ADDR')].compact.join(', ')
    response = http.start { |session| session.get(env.fetch('PATH_INFO'), headers) }
    [response.code.to_i, response.to_hash.transform_values { |value| value.join(', ') }.except('transfer-encoding'), [response.body]]
  end

  def self.forwarded_headers(env)
    env.select { |key, _| key.start_with?('HTTP_') }.transform_keys { |key| key.delete_prefix('HTTP_').tr('_', '-') }
  end
end

if $0 == __FILE__
  RateLimitServerOwnership.boot
  mode = ARGV.fetch(0)
  result = case mode
           when 'prepare', 'down', 'up' then RateLimitSchemaCommands.public_send(mode)
           when 'increment', 'audit', 'housekeeping', 'expiration' then RateLimitCounterCommands.public_send(mode)
           when 'server' then RateLimitHttpServer.run
           when 'alb' then RateLimitAlbModel.run
           else raise 'Unknown rate-limit fixture mode'
           end
  unless %w[server alb].include?(mode)
    path = ENV.fetch('REQUEST_RATE_RESULT')
    raise 'Foreign result path' unless File.dirname(path) == ENV.fetch('REQUEST_RATE_SCRATCH') && File.basename(path).match?(/\Aresult-[a-f0-9]{16}\.json\z/)

    File.write(path, JSON.generate(result), mode: 'wx', perm: 0o600)
  end
end
