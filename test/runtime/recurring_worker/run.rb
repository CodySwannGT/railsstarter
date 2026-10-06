# frozen_string_literal: true

# Actual scheduler/worker acceptance in a caller-owned MySQL test resource.
# Never loads rails_helper, prepares databases, or resets existing schemas.
require 'json'
require 'digest'
require 'securerandom'
require_relative 'isolation'

# Runs genuine command and application class tasks through Solid Queue.
class RecurringWorker
  include RecurringWorkerScratch
  include RecurringWorkerIsolation
  include RecurringWorkerAws

  # @param mode [String] positive run or controlled sensitivity experiment
  # @param output [String] private evidence file under tmp/66-native-runtime
  def initialize(mode, output)
    @mode = mode
    @output = File.expand_path(output, ROOT)
    @token = SecureRandom.hex(8)
    @directory = File.expand_path(ENV.fetch('RECURRING_SCRATCH'))
    @witness = File.join(@directory, "command-#{@token}.json")
    @aws_calls = []
    @mutex = Mutex.new
    @result = { mode: mode, token: @token, success: false }
  end

  # @return [Boolean] strict completion acceptance, with evidence on failure
  def run
    validate_environment!
    boot

    execute
    @result[:success] = completion?
  ensure
    finalize
  end

  private

  # @return [void] actual app boot in a synthetic queue adapter boundary
  def boot
    configure_aws
    require File.join(ROOT, 'config/application')
    Rails.application.config.active_job.queue_adapter = :solid_queue
    Rails.application.config.solid_queue.connects_to = { database: { writing: :queue, reading: :queue } }
    Rails.application.initialize!
    prepare_owned_schemas
    Rails.application.eager_load!
    @result[:boot_aws_calls] = @aws_calls.dup
    raise 'Finished job preservation is required' unless SolidQueue.preserve_finished_jobs
  end

  # @return [void] stop/join real processes before writing private evidence
  def finalize
    @scheduler&.stop
    @workers&.reverse_each(&:stop)
    if defined?(SolidQueue::Process) && @result[:databases]
      @result[:remaining_processes] = SolidQueue::Process.pluck(:id)
      @result[:success] = false if @result[:remaining_processes].any?
    end
    @result[:aws_calls] = @aws_calls
    @result[:error] = "#{$!.class}: #{$!.message}" if $!
    File.write(@output, JSON.pretty_generate(@result)) if @validated
  end

  # @param operation [String] real AWS operation
  # @param params [Hash] consumed SDK request parameters
  # @param successful [Boolean] authored response succeeds
  # @return [void]
  def record_call(operation, params, successful)
    job = ActiveSupport::ExecutionContext.to_h[:job] if defined?(ActiveSupport::ExecutionContext)
    @mutex.synchronize do
      @aws_calls << { operation: operation, params: params, successful: successful,
                      active_job_id: job&.job_id, job_class: job&.class&.name, queue_name: job&.queue_name }
    end
  end

  # Start genuine asynchronous scheduler/worker processes from current config.
  # @return [void]
  def execute
    build_schedule
    build_processes
    start_and_schedule
    observe_jobs
  end

  # @return [Array<String>] unique task keys for this run
  def task_keys = [@command_key, @class_key]

  # @return [void] controlled short schedules, actual original task kinds
  def build_schedule
    definitions = ActiveSupport::ConfigurationFile.parse(File.join(ROOT, 'config/recurring.yml')).fetch('development')
    @command_key = "66_command_#{@token}"
    @class_key = "66_class_#{@token}"
    command = definitions.fetch('heartbeat').fetch('command')
    command += "; raise '66 controlled command failure'" if @mode == 'command-failure'
    command += "; File.write(#{@witness.inspect}, #{JSON.generate(token: @token, effect: 'genuine recurring command completed').inspect})"
    @schedule = { @command_key => { command: command, schedule: '* * * * * *' },
                  @class_key => definitions.fetch('periodic_cloudwatch_metrics').merge('schedule' => '* * * * * *') }
  end

  # @return [void] actual current configuration process descriptors
  def build_processes
    schedule_file = File.join(@directory, "schedule-#{@token}.yml")
    File.write(schedule_file, YAML.dump('test' => @schedule))
    configuration = SolidQueue::Configuration.new(mode: :async, config_file: Rails.root.join('config/queue.yml'),
                                                  recurring_schedule_file: schedule_file)
    raise configuration.errors.full_messages.join(', ') unless configuration.valid?

    descriptors = configuration.configured_processes
    worker_descriptors = descriptors.select { |descriptor| descriptor.kind == :worker }
    omit_queue(worker_descriptors)
    @result[:worker_attributes] = worker_descriptors.map(&:attributes)
    record_installed_sources
    @workers = worker_descriptors.map(&:instantiate)
    @scheduler = descriptors.find { |descriptor| descriptor.kind == :scheduler }.instantiate
  end

  # @param descriptors [Array] real current worker descriptors
  # @return [void] controlled queue-omission sensitivity only
  def omit_queue(descriptors)
    omitted = { 'omit-command' => 'solid_queue_recurring', 'omit-class' => 'default' }[@mode]
    return unless omitted

    remaining = %w[solid_queue_recurring default] - [omitted]
    original = descriptors.map do |descriptor|
      SolidQueue::QueueSelector.new(descriptor.attributes[:queues], SolidQueue::ReadyExecution).raw_queues
    end
    raise 'Omission controls require the original all-queue worker selection' unless original.any? && original.all?(['*'])

    @result[:queue_omission] = { original: original, omitted: omitted, selected: remaining }
    descriptors.each { |descriptor| descriptor.attributes[:queues] = remaining.dup }
  end

  # @return [void] installed scheduling and worker API identities
  def record_installed_sources
    @result[:installed_source_hashes] = [SolidQueue::Worker.instance_method(:start).source_location.first,
                                         SolidQueue::Worker.instance_method(:poll).source_location.first,
                                         SolidQueue::Scheduler.instance_method(:run).source_location.first].uniq.index_with do |path|
      Digest::SHA256.file(path).hexdigest
    end
  end

  # @return [void] wait for real registration and persisted recurring executions
  def start_and_schedule
    (@workers + [@scheduler]).each { |process| process.mode = :async }
    @result[:process_mode] = 'async'
    (@workers + [@scheduler]).each(&:start)
    wait_until?(8) { @workers.all?(&:process_id) && @scheduler.process_id }
    @result[:processes] = SolidQueue::Process.all.map(&:attributes)
    wait_until?(8) { task_keys.all? { |key| SolidQueue::RecurringExecution.exists?(task_key: key) } }
    @scheduler.stop
    @scheduler = nil
    settle_executions
  end

  # @return [void] detect late scheduler callbacks across a full shortened period
  def settle_executions
    before = SolidQueue::RecurringExecution.where(task_key: task_keys).pluck(:id).sort
    sleep 1.1
    @execution_ids = SolidQueue::RecurringExecution.where(task_key: task_keys).pluck(:id).sort
    raise 'Late scheduler callback after stop' unless before == @execution_ids
  end

  # @return [void] capture persisted job/execution identities and statuses
  def observe_jobs
    @result[:tasks] = SolidQueue::RecurringTask.where(key: task_keys).map(&:attributes)
    executions = SolidQueue::RecurringExecution.where(task_key: task_keys)
    @result[:recurring_executions] = executions.map(&:attributes)
    ids = executions.pluck(:job_id)
    wait_until?(3, required: false) { SolidQueue::Job.where(id: ids, finished_at: nil).none? }
    record_job_status(ids)
    raise 'Recurring execution inventory changed after drain' unless executions.pluck(:id).sort == @execution_ids
  end

  # @param ids [Array<Integer>] only persisted jobs linked to this run's task keys
  # @return [void] real terminal, ready, claimed and failed states
  def record_job_status(ids)
    @result[:jobs] = SolidQueue::Job.where(id: ids).map(&:attributes)
    @result[:ready] = SolidQueue::ReadyExecution.where(job_id: ids).map(&:attributes)
    @result[:claimed] = SolidQueue::ClaimedExecution.where(job_id: ids).map(&:attributes)
    @result[:failed] = SolidQueue::FailedExecution.where(job_id: ids).map(&:attributes)
    @result[:command_witness] = JSON.parse(File.read(@witness)) if File.exist?(@witness)
    @result[:unfinished] = SolidQueue::Job.where(id: ids, finished_at: nil).pluck(:id)
  end

  # @param seconds [Numeric] bounded real clock deadline
  # @param required [Boolean] timeout raises when the observation is mandatory
  # @yield poll the actual persisted state
  # @return [Boolean] condition observed before deadline
  def wait_until?(seconds, required: true)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
    loop do
      return true if yield
      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.03
    end
    raise 'Timed out observing actual scheduler/worker state' if required

    false
  end

  # Terminal status AND meaningful task effects are both required.
  # @return [Boolean] strict authored acceptance
  def completion?
    queues = @result[:jobs].group_by { |job| job['class_name'] }.transform_values { |jobs| jobs.map { |job| job['queue_name'] }.uniq }
    @result[:completion_checks] = {
      metric_success: metric_success?,
      execution_mapping: execution_mapping?,
      zero_aws_boot: @result[:boot_aws_calls].empty? && !ENV.key?('AWS_BOOTSTRAP_ENABLED'),
      genuine_queues: queues == { 'SolidQueue::RecurringJob' => ['solid_queue_recurring'], 'PublishCloudWatchMetricsJob' => ['default'] },
      command_effect: command_effect?,
      terminal_jobs: terminal_jobs?
    }
    @result[:completion_checks].values.all?
  end

  # @return [Boolean] durable effect produced only by genuine scheduled command
  def command_effect?
    @result.dig(:command_witness, 'token') == @token &&
      @result.dig(:command_witness, 'effect') == 'genuine recurring command completed'
  end

  # @return [Boolean] no unfinished, ready, claimed or failed linked jobs
  def terminal_jobs?
    @result[:unfinished].empty? && @result[:jobs].all? { |job| job['finished_at'] } &&
      %i[ready claimed failed].all? { |kind| @result[kind].empty? }
  end

  # @return [Boolean] every scheduled execution maps to its genuine job kind/queue
  def execution_mapping?
    expectations = { @command_key => ['SolidQueue::RecurringJob', 'solid_queue_recurring'],
                     @class_key => %w[PublishCloudWatchMetricsJob default] }
    executions = @result[:recurring_executions]
    jobs = @result[:jobs].index_by { |job| job['id'] }
    executions.pluck('task_key').uniq.sort == task_keys.sort &&
      executions.size == jobs.size && executions.all? do |execution|
        job = jobs[execution['job_id']]
        job && expectations[execution['task_key']] == [job['class_name'], job['queue_name']]
      end
  end

  # @return [Boolean] consumed successful real SDK metric with validated fields
  def metric_success?
    jobs = @result[:jobs].select { |job| job['class_name'] == 'PublishCloudWatchMetricsJob' }
    jobs.any? && jobs.all? do |job|
      @aws_calls.any? { |call| valid_metric_call?(call, job['active_job_id']) }
    end
  end

  # @param call [Hash] real SDK callback witness
  # @param job_id [String] exact scheduled application's Active Job id
  # @return [Boolean] successful current job's intended CloudWatch effect
  def valid_metric_call?(call, job_id)
    return false unless call[:operation] == 'put_metric_data' && call[:successful] && call[:active_job_id] == job_id

    params = call[:params]
    data = params[:metric_data].first
    call[:job_class] == 'PublishCloudWatchMetricsJob' && call[:queue_name] == 'default' &&
      params[:namespace] == 'Your Project/BackgroundJobs' && data[:metric_name] == 'PendingJobs' &&
      data[:unit] == 'Count' && positive_integer_count?(data[:value])
  end

  # @param value [Numeric] actual consumed metric count, SDK coerces integers to float
  # @return [Boolean] valid positive integral pending job count
  def positive_integer_count?(value)
    value.is_a?(Numeric) && value >= 1 && value.to_i == value
  end
end

if $0 == __FILE__
  mode, output = ARGV
  begin
    success = RecurringWorker.new(mode || 'normal', output || File.join(ENV.fetch('RECURRING_SCRATCH'), 'result.json')).run
    exit(success ? 0 : 1)
  rescue StandardError => error
    warn "RECURRING_WORKER_FAILURE=#{error.class}: #{error.message}"
    exit 1
  end
end
