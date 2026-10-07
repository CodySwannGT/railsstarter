# frozen_string_literal: true

# The seed runs in the old installed bundle. Upgrade reads the identical physical
# schemas before and after the official namespaced migration, never schema-load.
require_relative 'resource'
require_relative 'sdk_boundary'
require 'base64'
require 'open3'

resource = DependencyResource.validate!
physical = DependencyResource.physical!(resource)
Aws.config.update(stub_responses: true, region: 'us-east-1',
                  credentials: Aws::Credentials.new('synthetic-80', 'synthetic-80'))
require File.join(DependencyResource::ROOT, 'config/application')
Rails.application.config.active_job.queue_adapter = :solid_queue
Rails.application.config.solid_queue.connects_to = { database: { writing: :queue, reading: :queue } }
require File.join(DependencyResource::ROOT, 'config/environment')

# Ordinary ActiveJob serialization is the persisted compatibility boundary.
class DependencyPreservedJob < ApplicationJob
  queue_as :default

  # @param payload [String] authored UTF8 data from the old bundle
  # @return [void] observable effect outside execution bookkeeping
  def perform(payload)
    File.open(File.join(ENV.fetch('DEPENDENCY80_SCRATCH'), 'job-effects.jsonl'), 'a') do |file|
      file.puts(JSON.generate(job_id: job_id, payload: payload))
    end
  end
end

# Existing concurrency states are produced through the actual old ActiveJob
# adapter. No application feature or batch API is introduced.
class DependencyConcurrencyJob < DependencyPreservedJob
  limits_concurrency to: 1, key: ->(payload) { "dependency80-#{payload}" }, duration: 1.hour
end

# @return [Hash] rows from all existing Solid state tables before producers run
def solid_witness
  tables = %w[solid_queue_jobs solid_queue_ready_executions solid_queue_scheduled_executions
              solid_queue_blocked_executions solid_queue_claimed_executions solid_queue_failed_executions
              solid_queue_processes solid_queue_semaphores]
  queue = SolidQueue::Record.connection_pool.with_connection do |connection|
    tables.to_h do |table|
      rows = connection.select_all("SELECT * FROM #{connection.quote_table_name(table)} ORDER BY id").to_a
      rows.each { |row| row.delete('batch_id') }
      [table, rows]
    end
  end
  binary_witness(queue: queue, cable: SolidCable::Message.order(:id).map(&:attributes),
                 cache: SolidCache::Entry.order(:id).map(&:attributes))
end

# @param value [Object] actual database values, including arbitrary binary cache
# @return [Object] lossless JSON witness with no UTF8 coercion of stored bytes
def binary_witness(value)
  case value
  when Hash then value.transform_values { |item| binary_witness(item) }
  when Array then value.map { |item| binary_witness(item) }
  when String then value.encoding == Encoding::BINARY ? { binary: Base64.strict_encode64(value) } : value
  else value
  end
end

SolidCable::Record.connects_to(database: { writing: :cable })
SolidCache::Record.connects_to(database: { writing: :cache })
ActiveJob::Base.queue_adapter = :solid_queue
scratch = resource.fetch('scratch')
ENV['DEPENDENCY80_SCRATCH'] = scratch
mode = ARGV.fetch(0)
case mode
when 'seed', 'prepare'
  raise 'All schemas must be empty before the only schema load' unless physical.all? { |role| role[:tables].empty? }

  schemas = { 'primary' => 'schema', 'queue' => 'queue_schema', 'cache' => 'cache_schema', 'cable' => 'cable_schema' }
  schema_root = ENV.fetch('DEPENDENCY80_BASELINE_SCHEMAS', File.join(DependencyResource::ROOT, 'db'))
  resource.fetch('configs').reject(&:replica?).each do |config|
    tasks = ActiveRecord::Tasks::DatabaseTasks
    tasks.send(:with_temporary_pool, config) do
      tasks.load_schema(config, :ruby, File.join(schema_root, "#{schemas.fetch(config.name)}.rb"))
    end
  end
  if mode == 'prepare'
    puts JSON.generate(physical: physical, prepared: true)
    exit 0
  end
  ready = DependencyPreservedJob.perform_later('ready café 😀')
  scheduled = DependencyPreservedJob.set(wait: 1.hour).perform_later('scheduled café 😀')
  failed = DependencyPreservedJob.perform_later('failed café 😀')
  failed_record = SolidQueue::Job.find(failed.provider_job_id)
  failed_record.ready_execution.destroy!
  SolidQueue::FailedExecution.create!(job: failed_record, error: JSON.generate('message' => 'authored prior failure'))
  DependencyConcurrencyJob.perform_later('concurrent café 😀')
  blocked = DependencyConcurrencyJob.perform_later('concurrent café 😀')
  raise 'Actual old adapter did not block second concurrency job' unless SolidQueue::BlockedExecution.exists?(job_id: blocked.provider_job_id)

  claimed = DependencyPreservedJob.set(queue: 'dependency80-claimed').perform_later('claimed café 😀')
  owner = SolidQueue::Process.register(kind: 'Worker', name: 'dependency80-preserved-claim',
                                       pid: Process.pid, hostname: Socket.gethostname, metadata: {})
  claim = SolidQueue::ReadyExecution.claim('dependency80-claimed', 1, owner.id)
  raise 'Actual old claim API did not claim the authored job' unless claim.one? && claim.first.job_id == claimed.provider_job_id.to_i

  SolidCable::Message.broadcast('dependency80-retained', 'retained café 😀')
  store = SolidCache::Store.new(namespace: 'dependency80')
  store.write('retained', 'cached café 😀')
  raise 'Native cache roundtrip failed' unless store.read('retained') == 'cached café 😀'

  witness = solid_witness
  File.write(File.join(scratch, 'before.json'), JSON.generate(witness))
  puts JSON.generate(physical: physical, versions: %w[solid_queue solid_cable solid_cache].index_with { |name| Gem.loaded_specs.fetch(name).version.to_s },
                     ready_id: ready.provider_job_id, scheduled_id: scheduled.provider_job_id, failed_id: failed.provider_job_id,
                     blocked_id: blocked.provider_job_id, claimed_id: claimed.provider_job_id,
                     witness: witness, witness_sha256: Digest::SHA256.hexdigest(JSON.generate(witness)))
when 'upgrade', 'verify'
  before = JSON.parse(File.read(File.join(scratch, 'before.json')))
  actual = JSON.parse(JSON.generate(solid_witness))
  if actual != before
    puts JSON.generate(preservation_mismatch: { mode: mode, actual: actual, before: before })
    raise 'Rows changed during bundle switch'
  end

  puts JSON.generate(bundle_switch_preserved: true, physical: physical,
                     before_sha256: Digest::SHA256.hexdigest(JSON.generate(before)))

  settings = File.read(File.join(DependencyResource::ROOT, 'config/initializers/strong_migrations.rb'))
  committed, status = Open3.capture2('git', '-C', DependencyResource::ROOT, 'show', 'HEAD:config/initializers/strong_migrations.rb')
  ancestry = status.success? && committed == settings
  safe = StrongMigrations.target_version.to_s == '8.4' && StrongMigrations.safe_by_default &&
         StrongMigrations.check_enabled?(:add_index_columns) && ancestry
  puts JSON.generate(initializer_in_committed_ancestry: ancestry, target: StrongMigrations.target_version.to_s,
                     safe_by_default: StrongMigrations.safe_by_default, add_index_columns_enabled: StrongMigrations.check_enabled?(:add_index_columns))
  raise 'Dependent acceptance needs corrected77 committed initializer ancestry' unless safe

  if mode == 'upgrade'
    Rails.application.load_tasks
    Rake::Task['db:migrate:queue'].invoke
  end
  raise 'Old Solid rows changed in additive migration' unless JSON.parse(JSON.generate(solid_witness)) == before
  raise 'Native cache lost across bundle switch' unless SolidCache::Store.new(namespace: 'dependency80').read('retained') == 'cached café 😀'

  connection = SolidQueue::Record.connection
  raise 'Batch tables missing after actual migration' unless %w[solid_queue_batches solid_queue_batch_executions].all? { |table| connection.table_exists?(table) }
  raise 'Nullable batch column missing' unless connection.columns('solid_queue_jobs').any? { |column| column.name == 'batch_id' && column.null }
  raise 'Old jobs unexpectedly attached to batches' unless connection.select_value('SELECT COUNT(*) FROM solid_queue_jobs WHERE batch_id IS NOT NULL').zero?

  fingerprints = resource.fetch('configs').reject(&:replica?).map do |config|
    file = ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(config)
    { role: config.name, schema_file: file, source_sha1: Digest::SHA1.file(file).hexdigest,
      schema_up_to_date: ActiveRecord::Tasks::DatabaseTasks.schema_up_to_date?(config) }
  end
  puts JSON.generate(preserved: true, physical: physical, witness: before, queue_tables: connection.tables.sort,
                     schema_fingerprints: fingerprints)
else
  raise 'Unknown preservation mode'
end
