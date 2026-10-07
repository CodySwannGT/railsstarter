# frozen_string_literal: true

require 'json'
require 'digest'
require 'fileutils'
require 'stringio'
require 'socket'
require 'mysql2'

input = JSON.parse($stdin.read)
resource = input.fetch('resource')
root = File.realpath(input.fetch('root'))
output = input.fetch('output')
mode = input.fetch('mode')
result = { mode: mode, pid: Process.pid, root: root, phase: 'preflight', s3_requests: [], transports: 0 }
private_write = lambda do |path, data|
  File.open(path, 'w', 0o600) { |file| file.write(data) }
end
begin
  raise 'Unknown fixture operation' unless %w[attach read denied inspect assets migration prepare].include?(mode)

  owner = JSON.parse(File.read(File.join(File.dirname(root), '.owner.json')))
  raise 'Scratch owner mismatch' unless owner.fetch('nonce') == resource.fetch('nonce') && owner.fetch('source_root') == resource.fetch('source_root')
  raise 'Unsafe output' unless File.dirname(output) == File.dirname(root)
  raise 'Unsafe runtime profile' unless %w[staging production test development].include?(ENV.fetch('RAILS_ENV', nil)) && ENV['RACK_ENV'] == ENV['RAILS_ENV']
  raise 'Unexpected database URL' if ENV.keys.any? { |key| key.match?(/DATABASE_URL|_DB_URL|\AOTEL_/) }
  raise 'Unsafe DB settings' unless ENV['DATABASE_SSL'] == 'false' && ENV['DATABASE_IAM_AUTH'] == 'false' && resource.fetch('host') == '127.0.0.1' && resource.fetch('port') != 3306

  # Independent positive owned identity check precedes Rails, helpers and schema access in EVERY app.
  resource.fetch('databases').each_value do |database|
    raise 'Not a test-only identity' unless database.match?(/\Arailsstarter73_(?:test_[a-f0-9]{12}(?:_(?:queue|cache|cable))?|[a-f0-9]{12}(?:_(?:queue|cache|cable))?_test)\z/)

    connection = Mysql2::Client.new(host: resource.fetch('host'), port: resource.fetch('port'), username: resource.fetch('database_user'), password: "synthetic-app-#{resource.fetch('nonce')}",
                                    database: database)
    identity = connection.query('SELECT VERSION() v,@@server_uuid uuid,@@hostname hostname,@@port port,DATABASE() db').first
    raise 'Physical/logical identity mismatch' unless resource.fetch('server_identity') == [identity['v'], identity['uuid'], identity['hostname'],
                                                                                            identity['port'].to_s] && identity['db'] == database

    grants = connection.query('SHOW GRANTS').map(&:values).flatten
    raise 'Unexpected privileges' unless grants.length == 5 && grants.grep(/ON \*\.\*/).all? { |grant| grant.start_with?('GRANT USAGE ON') }
    raise 'Wrong scoped database grants' unless resource.fetch('databases').values.all? do |name|
      grants.any? { |grant| grant.include?("`#{name.gsub('_') { '\\_' }}`.*") }
    end
    raise 'Suite preparation DB not fresh' if mode == 'prepare' && connection.query('SHOW TABLES').any?

    connection.close
  end
  result[:identity_preflight] = true
  # Reject actual external Ruby sockets before any SDK or application code runs.
  tripwire = Module.new do
    define_method(:new) { |*| raise 'Storage acceptance: external socket blocked' }
    define_method(:open) { |*| raise 'Storage acceptance: external socket blocked' }
  end
  TCPSocket.singleton_class.prepend(tripwire)
  Socket.singleton_class.prepend(Module.new do
    define_method(:tcp) { |*| raise 'Storage acceptance: external socket blocked' }
    define_method(:getaddrinfo) { |*| raise 'Storage acceptance: external DNS blocked' }
  end)
  begin
    TCPSocket.new('198.51.100.1', 443)
    raise 'Network tripwire failed to reach'
  rescue RuntimeError => error
    raise unless error.message.include?('external socket blocked')

    result[:network_control] = error.message
  end
  require 'aws-sdk-s3'
  require 'active_support/core_ext/enumerable'
  sdk_guard = Module.new do
    define_method(:call) do |*|
      result[:transports] += 1
      raise 'Storage acceptance: provider transport blocked'
    end
  end
  Seahorse::Client::NetHttp::Handler.prepend(sdk_guard)
  # Reaching control uses the real unstubbed client/transport handler; it cannot reach a provider.
  begin
    Aws::S3::Client.new(region: 'us-east-1', credentials: Aws::Credentials.new('synthetic', 'synthetic'), stub_responses: false, retry_limit: 0).list_buckets
    raise 'SDK transport detector did not reach'
  rescue RuntimeError => error
    raise unless error.message.include?('provider transport blocked')

    result[:sdk_transport_control] = error.message
  end
  # The C mysql2 adapter bypasses Ruby sockets; constrain its actual connection arguments too.
  Mysql2::Client.prepend(Module.new do
    define_method(:initialize) do |options = {}, &block|
      settings = options.transform_keys(&:to_sym)
      safe = settings[:host] == '127.0.0.1' && settings[:port].to_i == resource.fetch('port') && resource.fetch('databases').value?(settings[:database]) &&
             settings[:username] == resource.fetch('database_user') && settings[:password] == "synthetic-app-#{resource.fetch('nonce')}" &&
             !settings[:socket] && !settings[:url]
      raise 'Storage acceptance: unsafe mysql2 connection' unless safe

      super(options, &block)
    end
  end)
  result[:transports] = 0 # Actual subsequent application transport count, control recorded separately.
  callbacks = Aws::S3::Client.api.operation_names.index_with { |operation| ->(_) { raise "Unexpected S3 operation #{operation}" } }
  store = input.fetch('object_store')
  callbacks[:put_object] = lambda do |context|
    params = context.params
    io = params.fetch(:body)
    bytes = io.respond_to?(:read) ? io.read : io.to_s
    result[:s3_requests] << { operation: 'put_object', bucket: params[:bucket], key: params[:key], bytes: bytes.bytesize, sha256: Digest::SHA256.hexdigest(bytes), content_md5: params[:content_md5] }
    if mode == 'denied'
      Aws::S3::Errors::AccessDenied.new(context, '73 controlled upload denial')
    else
      path = File.join(store, Digest::SHA256.hexdigest([params[:bucket], params[:key]].join("\0")))
      private_write.call(path, bytes)
      { etag: Digest::MD5.hexdigest(bytes) }
    end
  end
  callbacks[:get_object] = lambda do |context|
    params = context.params
    result[:s3_requests] << { operation: 'get_object', bucket: params[:bucket], key: params[:key] }
    path = File.join(store, Digest::SHA256.hexdigest([params[:bucket], params[:key]].join("\0")))
    if File.file?(path)
      bytes = File.binread(path)
      { body: StringIO.new(bytes), content_length: bytes.bytesize }
    else
      Aws::S3::Errors::NoSuchKey.new(context, '73 object absent')
    end
  end
  Aws.config.update(stub_responses: true, s3: { stub_responses: callbacks })
  require 'rails'
  require 'active_record'
  require 'active_record/database_configurations'
  require 'active_support/configuration_file'
  raw = ActiveSupport::ConfigurationFile.parse(File.join(root, 'config/database.yml'))
  configs = ActiveRecord::DatabaseConfigurations.new(raw).configs_for(env_name: ENV.fetch('RAILS_ENV'), include_hidden: true)
  raise "Wrong resolved role inventory: #{configs.map(&:name).sort.inspect}" unless configs.map(&:name).sort == %w[cache cable primary primary_replica queue].sort

  configs.each do |config|
    options = config.configuration_hash
    expected = resource.fetch('databases').fetch(config.name == 'primary_replica' ? 'primary' : config.name)
    safe = config.database == expected && options[:adapter] == 'mysql2' &&
           options[:host] == '127.0.0.1' && options[:port].to_i == resource.fetch('port') &&
           options[:username] == resource.fetch('database_user') && options[:password] == "synthetic-app-#{resource.fetch('nonce')}" &&
           !options[:socket] && !options[:url] && !options[:aws_rds_iam_auth] && !options[:ssl_mode]
    raise "Unsafe resolved role #{config.name}" unless safe
  end
  result[:resolved_roles] = configs.map { |config| { role: config.name, database: config.database } }
  result[:phase] = 'boot'
  if mode == 'assets'
    ARGV.replace(['assets:precompile'])
    load File.join(root, 'bin/rails')
  else
    require File.join(root, 'config/environment')
  end
  result[:selected_service] = Rails.application.config.active_storage.service.to_s
  result[:service_class] = ActiveStorage::Blob.service.class.name
  if mode == 'prepare'
    raise 'Suite preparation must use test profile' unless Rails.env.test?

    require 'rake'
    Rails.application.load_tasks
    Rake::Task['db:migrate:primary'].invoke
    %w[queue cache cable].each { |role| Rake::Task["db:schema:load:#{role}"].invoke }
    schema_path = File.join(root, 'db/schema.rb')
    private_write.call(File.join(File.dirname(root), 'suite-primary-schema.rb'), File.read(schema_path))
    result[:generated_schema_sha256] = Digest::SHA256.file(schema_path).hexdigest
    result[:phase] = 'complete'
    result[:success] = true
    exit 0
  end
  if %w[assets inspect].include?(mode)
    if mode == 'assets'
      manifest = File.join(root, 'public/assets/.manifest.json')
      raise 'Actual precompile manifest missing' unless File.file?(manifest) && JSON.parse(File.read(manifest)).any?

      result[:asset_manifest_sha256] = Digest::SHA256.file(manifest).hexdigest
      begin
        ActiveStorage::Blob.service.upload('build-upload-must-fail', StringIO.new('synthetic'))
        raise 'Build adapter allowed an upload'
      rescue ActiveStorage::Service::UploadBuildOnlyService::Unavailable => error
        result[:build_upload_control] = error.message
      end
    end
    result[:phase] = 'complete'
    result[:success] = true
    private_write.call(output, JSON.pretty_generate(result))
    exit 0
  end
  ActiveJob::Base.queue_adapter = :test
  result[:phase] = 'metadata'
  ActiveRecord::Base.establish_connection(configs.find { |config| config.name == 'primary' }.configuration_hash)
  connection = ActiveRecord::Base.connection
  if mode == 'migration'
    raise 'Migration proof DB not fresh' unless connection.tables.empty?

    engine_path = File.join(Gem::Specification.find_by_name('activestorage').full_gem_path, 'db/migrate/20170806125915_create_active_storage_tables.rb')
    host_path = Dir[File.join(root, 'db/migrate/*_create_active_storage_tables.active_storage.rb')].fetch(0)
    dump_schema = lambda do
      schema = StringIO.new
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, schema)
      schema.string
    end
    migrations = [engine_path, host_path].map do |path|
      namespace = Module.new
      namespace.module_eval(File.read(path), path)
      namespace.const_get(:CreateActiveStorageTables).new
    end
    migrations.first.migrate(:up)
    original_schema = dump_schema.call
    migrations.first.migrate(:down)
    raise 'Engine migration down left metadata tables' unless connection.tables.empty?

    migrations.last.migrate(:up)
    host_schema = dump_schema.call
    raise 'Host migration schema differs from engine' unless host_schema == original_schema

    migrations.last.migrate(:down)
    result[:migration_down_clean] = connection.tables.empty?
    raise 'Host migration down left metadata tables' unless result[:migration_down_clean]

    migrations.last.migrate(:up)
    roundtrip_schema = dump_schema.call
    raise 'Host migration roundtrip changed schema' unless roundtrip_schema == host_schema

    { 'engine-schema.rb' => original_schema, 'host-schema.rb' => host_schema, 'roundtrip-schema.rb' => roundtrip_schema }.each do |name, bytes|
      private_write.call(File.join(File.dirname(root), name), bytes)
    end
    result[:schema_matches_engine] = true
    result[:migration_roundtrip_equal] = true
    result[:engine_migration_sha256] = Digest::SHA256.file(engine_path).hexdigest
    result[:host_migration_sha256] = Digest::SHA256.file(host_path).hexdigest
    result[:generated_schema_sha256] = Digest::SHA256.hexdigest(host_schema)
    result[:host_tables] = connection.tables.sort
    result[:phase] = 'complete'
    result[:success] = true
    exit 0
  end
  if input['prepare']
    raise 'Metadata DB not fresh' unless connection.tables.empty?

    ActiveRecord::MigrationContext.new(File.join(root, 'db/migrate')).migrate
    # Record only the actual host metadata schema BEFORE the fixture owner table.
    schema = StringIO.new
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, schema)
    result[:host_schema_sha256] = Digest::SHA256.hexdigest(schema.string)
    result[:host_tables] = connection.tables.sort
    connection.create_table(:storage_witnesses) { |table| table.string :label }
  end
  witness = Class.new(ApplicationRecord)
  Object.const_set(:StorageWitness, witness)
  witness.table_name = 'storage_witnesses'
  witness.has_one_attached :payload
  result[:phase] = 'attachment'
  if mode == 'read'
    record = witness.find(input.fetch('owner_id'))
    result[:owner_id] = record.id
    blob = record.payload.blob
    result[:key] = blob.key
    result[:service_name] = blob.service_name
    result[:service_class] = blob.service.class.name
    bytes = record.payload.download
    result[:download_sha256] = Digest::SHA256.hexdigest(bytes)
    result[:download_bytes] = bytes.bytesize
    raise 'Stored object content mismatch' unless bytes == input.fetch('payload').b
  else
    record = witness.create!(label: '73 synthetic witness')
    result[:owner_id] = record.id
    record.payload.attach(io: StringIO.new(input.fetch('payload').b), filename: 'witness.bin', content_type: 'application/octet-stream', identify: false)
    blob = record.payload.blob
    result[:key] = blob.key
    result[:service_name] = blob.service_name
    result[:service_class] = blob.service.class.name
    result[:input_sha256] = Digest::SHA256.hexdigest(input.fetch('payload'))
    result[:input_bytes] = input.fetch('payload').bytesize
  end
  result[:metadata_rows] =
    connection.select_all('SELECT b.id,b.key,b.service_name,b.byte_size,a.record_id,a.record_type FROM active_storage_blobs b LEFT JOIN active_storage_attachments a ON a.blob_id=b.id').to_a
  result[:phase] = 'complete'
  result[:success] = true
rescue SystemExit
  raise
rescue StandardError, LoadError => error # Preserve real boot/after-commit failure and its phase in a private result.
  result[:success] = false
  result[:error] = { class: error.class.name, message: error.message, backtrace: error.backtrace&.first(12) }
  if defined?(connection) && connection
    begin
      result[:failure_metadata_rows] =
        connection.select_all('SELECT b.id,b.key,b.service_name,b.byte_size,a.record_id FROM active_storage_blobs b LEFT JOIN active_storage_attachments a ON a.blob_id=b.id').to_a
    rescue StandardError
      result[:failure_metadata_rows] = 'not available at this failure boundary'
    end
  end
ensure
  if result[:selected_service] && ActiveStorage::Blob.service.respond_to?(:client)
    client = ActiveStorage::Blob.service.client.client
    result[:sdk_stubbed] = client.config.stub_responses.is_a?(Hash) || client.config.stub_responses == true
    result[:api_requests] = client.api_requests.map do |request|
      { operation: request[:operation_name].to_s, params: request[:params].slice(:bucket, :key, :content_md5, :content_type) }
    end
  end
  result[:disk_files] = %w[storage tmp/storage].flat_map { |directory| Dir[File.join(root, directory, '**/*')].select { |path| File.file?(path) }.map { |path| path.delete_prefix("#{root}/") } }
  private_write.call(output, JSON.pretty_generate(result))
end
exit(result[:success] ? 0 : 1)
