# frozen_string_literal: true

# The existing primary app remains untouched. These authored boundaries select
# real database adapters in memory because the ordinary test config uses fakes.
require_relative 'resource'
require_relative 'sdk_boundary'
require 'digest'
require 'timeout'
require 'rbconfig'

resource = DependencyResource.validate!
physical = DependencyResource.physical!(resource)
Aws.config.update(stub_responses: true, region: 'us-east-1',
                  credentials: Aws::Credentials.new('synthetic-80', 'synthetic-80'))
require File.join(DependencyResource::ROOT, 'config/application')
Rails.application.config.active_job.queue_adapter = :solid_queue
Rails.application.config.solid_queue.connects_to = { database: { writing: :queue, reading: :queue } }
require File.join(DependencyResource::ROOT, 'config/environment')
Rails.application.eager_load!
SolidCable::Record.connects_to(database: { writing: :cable })
SolidCache::Record.connects_to(database: { writing: :cache })
scratch = resource.fetch('scratch')
ENV['DEPENDENCY80_SCRATCH'] = scratch

# Matches the serialized old-bundle job, while preserving normal ActiveJob APIs.
class DependencyPreservedJob < ApplicationJob
  queue_as :default

  # @param payload [String] authored value retained across the upgrade
  # @return [void] independent job effect
  def perform(payload)
    File.open(File.join(ENV.fetch('DEPENDENCY80_SCRATCH'), 'job-effects.jsonl'), 'a') do |file|
      file.puts(JSON.generate(job_id: job_id, payload: payload))
    end
  end
end

class DependencyConcurrencyJob < DependencyPreservedJob
  limits_concurrency to: 1, key: ->(payload) { "dependency80-#{payload}" }, duration: 1.hour
end

if ARGV.first == 'cli'
  ARGV.replace(%w[start --mode async --skip-recurring])
  load File.join(DependencyResource::ROOT, 'bin/jobs')
  exit 0
end

# @param seconds [Numeric] bounded asynchronous observation
# @yieldreturn [Boolean] effect is visible in the actual runtime
# @return [void]
def wait_for(seconds = 5)
  Timeout.timeout(seconds) do
    sleep 0.02 until yield
  end
end

queue_config = SolidQueue::Configuration.new(mode: :async, config_file: Rails.root.join('config/queue.yml'), skip_recurring: true)
raise queue_config.errors.full_messages.join(', ') unless queue_config.valid?

processes = queue_config.configured_processes.map(&:instantiate)
ready = SolidQueue::Job.find_by!(class_name: 'DependencyPreservedJob', scheduled_at: ..Time.current, finished_at: nil)
job_id = ready.active_job_id
scheduled_ids = SolidQueue::ScheduledExecution.pluck(:job_id)
failed_ids = SolidQueue::FailedExecution.pluck(:job_id)
blocked_ids = SolidQueue::BlockedExecution.pluck(:job_id)
claimed_ids = SolidQueue::ClaimedExecution.pluck(:job_id)
raise 'Missing retained execution-state witnesses' unless blocked_ids.one? && claimed_ids.one?

# Only after preservation readback, model a normal owner shutdown through the
# actual API, which releases its claim back to ready for new workers.
SolidQueue::Process.find_by!(name: 'dependency80-preserved-claim').deregister
begin
  processes.each do |process|
    process.mode = :async
    process.start
  end
  wait_for { processes.all?(&:process_id) }
  wait_for { ready.reload.finished_at.present? }
  wait_for { SolidQueue::Job.where(id: blocked_ids + claimed_ids, finished_at: nil).none? }
  effects = File.readlines(File.join(scratch, 'job-effects.jsonl')).map { |line| JSON.parse(line) }
  raise 'Missing or duplicate persisted old job effect' unless effects.one? { |effect| effect['job_id'] == job_id && effect['payload'] == 'ready café 😀' }
  raise 'Preserved blocked/claimed job effects missing' unless effects.count { |effect| effect['payload'] == 'concurrent café 😀' } == 2 &&
                                                               effects.one? { |effect| effect['payload'] == 'claimed café 😀' }
  raise 'Future scheduled jobs consumed early' unless (scheduled_ids - SolidQueue::ScheduledExecution.pluck(:job_id)).empty?
  raise 'Prior failed jobs silently consumed' unless (failed_ids - SolidQueue::FailedExecution.pluck(:job_id)).empty?
ensure
  processes.reverse_each(&:stop)
end
raise 'Queue processes remain registered' if SolidQueue::Process.any?

trap('TERM') { raise Interrupt, 'Owned runtime interrupted' }
cli_log = File.join(scratch, 'jobs-cli.log')
cli_pid = Process.spawn(RbConfig.ruby, '-rbundler/setup', __FILE__, 'cli',
                        pgroup: true, out: cli_log, err: [:child, :out])
begin
  wait_for(15) { %w[Supervisor(async) Worker Dispatcher].all? { |kind| SolidQueue::Process.exists?(kind: kind, pid: cli_pid) } }
  cli_processes = SolidQueue::Process.order(:id).map(&:attributes)
rescue StandardError => error
  raise "#{error.class}: #{error.message}\nCLI log: #{File.read(cli_log)}\nRegistered: #{SolidQueue::Process.order(:id).map(&:attributes).to_json}"
ensure
  Process.kill('TERM', cli_pid)
  begin
    Timeout.timeout(15) { Process.waitpid(cli_pid) }
  rescue Timeout::Error
    Process.kill('KILL', -cli_pid)
    Process.waitpid(cli_pid)
  end
  cli_status = Process.last_status
end
raise 'CLI shutdown left registered queue processes' if SolidQueue::Process.any?
raise "CLI shutdown failed: #{File.read(cli_log)}" unless cli_status.success?

begin
  Process.kill(0, -cli_pid)
  raise 'CLI process group remained'
rescue Errno::ESRCH
  cli_group_absent = true
end

server = ActionCable::Server::Base.new
server.config.cable = { 'adapter' => 'solid_cable', 'connects_to' => { 'database' => { 'writing' => 'cable' } } }
adapter = ActionCable::SubscriptionAdapter::SolidCable.new(server)
delivered = Queue.new
subscribed = Queue.new
callback = ->(payload) { delivered << payload }
begin
  adapter.subscribe('dependency80-retained', callback, -> { subscribed << true })
  Timeout.timeout(5) { subscribed.pop }
  sleep 0.1
  raise 'Retained messages replayed unexpectedly' unless delivered.empty?

  adapter.unsubscribe('dependency80-retained', callback)
  adapter.subscribe('dependency80-live', callback, -> { subscribed << true })
  Timeout.timeout(5) { subscribed.pop }
  adapter.broadcast('dependency80-foreign', 'foreign')
  adapter.broadcast('dependency80-live', 'actual async café 😀')
  raise 'Cable payload bytes changed' unless Timeout.timeout(5) { delivered.pop }.b == 'actual async café 😀'.b

  wait_for { SolidCable::Message.exists?(channel: 'dependency80-live') }
  adapter.unsubscribe('dependency80-live', callback)
  adapter.broadcast('dependency80-live', 'after unsubscribe')
  adapter.broadcast('dependency80-shutdown', 'shutdown flush café 😀')
  adapter.shutdown
  stopped = true
  raise 'Unsubscribed callback delivered' unless delivered.empty?
  raise 'Retained cable message lost' unless SolidCable::Message.exists?(channel: 'dependency80-retained', payload: 'retained café 😀')
  raise 'Shutdown lost pending writer messages' unless SolidCable::Message.exists?(channel: 'dependency80-shutdown', payload: 'shutdown flush café 😀')
ensure
  adapter.shutdown unless stopped
  server.event_loop.stop
end

# Report the genuine NOT NULL violation produced by the async writer. A return
# from broadcast alone cannot prove either persistence or failure reporting.
class DependencyCableErrors
  attr_reader :errors

  # @return [void]
  def initialize
    @errors = Queue.new
  end

  # @param error [Exception] actual asynchronous persistence failure
  # @return [void]
  def report(error, **)
    errors << error
  end
end

subscriber = DependencyCableErrors.new
Rails.error.subscribe(subscriber)
writer = SolidCable::BatchedBroadcaster.new(batch_size: 1)
begin
  writer.broadcast('dependency80-invalid', nil)
  error = Timeout.timeout(5) { subscriber.errors.pop }
  raise 'Wrong async error witness' unless error.is_a?(ActiveRecord::NotNullViolation)
  raise 'Invalid async row persisted' if SolidCable::Message.exists?(channel: 'dependency80-invalid')
ensure
  writer.shutdown
  Rails.error.unsubscribe(subscriber)
end
raise 'Native cache value lost' unless SolidCache::Store.new(namespace: 'dependency80').read('retained') == 'cached café 😀'

require 'rack/mock'
requests = %w[/ /up].map do |path|
  response = Rack::MockRequest.new(Rails.application).get(path, 'REMOTE_ADDR' => '127.0.0.1')
  raise "Boot/render failed: #{path}" unless response.status == 200

  { path: path, status: response.status, content_type: response.content_type }
end
require 'jbuilder'
ApplicationController.prepend_view_path(__dir__)
json = ApplicationController.render(template: 'jbuilder', formats: [:json], locals: { payload: 'café 😀' }, layout: false)
raise 'Jbuilder rendering failed' unless JSON.parse(json) == { 'payload' => 'café 😀', 'numbers' => [1, 2] }

extensions = %w[mysql2 bootsnap].to_h do |name|
  path = $".find { |feature| feature.match?(%r{/#{name}/#{name}\.(?:so|bundle)\z}) }
  raise "Native extension missing: #{name}" unless path

  [name, { path: path, sha256: Digest::SHA256.file(path).hexdigest }]
end
puts JSON.generate(physical: physical, requests: requests, extensions: extensions,
                   job_effects: effects, scheduled_ids: scheduled_ids, failed_ids: failed_ids,
                   blocked_ids: blocked_ids, claimed_ids: claimed_ids,
                   cli_processes: cli_processes, cli_log: File.read(cli_log), cli_exit: cli_status.exitstatus, cli_group_absent: cli_group_absent,
                   queue_processes_stopped: SolidQueue::Process.none?, cable_delivery: true, cable_async_error: error.class.name,
                   cache_preserved: true, jbuilder: JSON.parse(json))
