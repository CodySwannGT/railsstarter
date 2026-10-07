# frozen_string_literal: true

require 'io/wait'

module SmokeConsumer
  # An immutable exit observation: safe to query without re-polling an operating process.
  class CommandStatus
    # Retain the executable basename and actual command termination status.
    # @param executable [String] command executable name
    # @param status [Process::Status, CommandExit] actual command termination status
    def initialize(executable, status)
      @executable = File.basename(executable)
      @status = status
    end

    # Reject missing prerequisites and unsuccessful command termination.
    # @return [void]
    # @raise [Error] executable is missing or command failed
    def require_success
      code = @status.exitstatus
      raise Error, "Essential prerequisite: executable #{@executable} unavailable in the declared PATH" if code == 127
      raise Error, "#{@executable} failed (exit #{code || @status.termsig})" unless @status.success?
    end
  end

  # Shared by the original fork execution boundary and the retained guardian.
  class ForkBoundary
    # Exit the fork directly without running inherited parent exit handlers.
    # @param status [Integer] direct child exit code
    # @return [void]
    def self.finish(status)
      exit! status # rubocop:disable Rails/Exit -- fork boundary, never inherited RSpec exit handlers.
    end
  end

  # A direct child is never signalled after it has been reaped: its PID cannot be reused while retained.
  class DirectChild
    # Retain the PID of a directly owned unreaped child.
    # @param pid [Integer] process ID to observe, signal, or reap
    def initialize(pid)
      @pid = pid
    end

    # Kill and reap the direct child unless it has already been reaped.
    # @return [void]
    def terminate
      return if reaped?

      Process.kill('KILL', @pid)
      reap
    rescue Errno::ESRCH
      reap
    end

    # Resume the direct child if it remains unreaped; tolerate disappearance.
    # @return [void]
    def resume
      Process.kill('CONT', @pid) unless reaped?
    rescue Errno::ESRCH
      nil
    end

    # Poll for reaping under a three-second deadline.
    # @return [void]
    def reap
      Deadline.new(3).poll('Direct child reap deadline exceeded') { reaped? }
    end

    private

    # Check the direct child with nonblocking wait and treat ECHILD as already reaped.
    # @return [Integer, true, nil] reaped PID, already-reaped marker, or still-running nil
    def reaped?
      Process.waitpid(@pid, Process::WNOHANG)
    rescue Errno::ECHILD
      true
    end
  end

  # Owns one pipe and the gate, status, output, or cleanup protocol carried through it.
  class PipeChannel
    attr_reader :reader, :writer

    # Allocate one IO pipe and retain both owned endpoints.
    def initialize
      @reader, @writer = IO.pipe
    end

    # Close the read endpoint unless already closed.
    # @return [void]
    def close_reader
      @reader.close unless @reader.closed?
    end

    # Close the write endpoint unless already closed.
    # @return [void]
    def close_writer
      @writer.close unless @writer.closed?
    end

    # Close both channel endpoints.
    # @return [void]
    def close
      close_reader
      close_writer
    end

    # Read the single release token and always close the read endpoint.
    # @return [Boolean]
    def allow_execution?
      @reader.read(1) == '1'
    ensure
      close_reader
    end

    # Write the single execution-release token.
    # @return [Integer]
    def send_token
      @writer.write('1')
    end

    # Write a JSON exit/signal receipt and close the writer, tolerating a broken pipe.
    # @param status [Process::Status] actual payload wait status
    # @return [void]
    def send_exit(status)
      @writer.write(JSON.generate('exitstatus' => status.exitstatus, 'termsig' => status.termsig))
    rescue Errno::EPIPE
      nil
    ensure
      close_writer
    end

    # Detect cleanup data or EOF without blocking the guardian.
    # @return [String, Boolean, nil] token/EOF truthiness, or no readable request
    def cleanup_requested?
      @reader.wait_readable(0) && @reader.read_nonblock(1)
    rescue EOFError
      true
    rescue IO::WaitReadable
      false
    end

    # Detach stdin and redirect stdout/stderr into this channel before exec.
    # @return [void]
    def redirect_output
      $stdin.reopen(File::NULL)
      $stdout.reopen(@writer)
      $stderr.reopen(@writer)
      close_writer
    end
  end

  # Owns the four channels connecting caller, guardian, and command payload.
  class CommandPipes
    # Channel endpoints closed in the caller after the guardian fork.
    PARENT_CLOSE = { gate: :close_reader, output: :close_writer, status: :close_writer, control: :close_reader }.freeze
    # Channel endpoints closed in the guardian side after the fork.
    CHILD_CLOSE = { gate: :close_writer, output: :close_reader, status: :close_reader, control: :close_writer }.freeze

    # Allocate the gate, control, output, and status pipe channels.
    def initialize
      @channels = {}
      %i[gate output status control].each { |role| @channels[role] = PipeChannel.new }
    end

    # Fetch one named gate, control, output, or status channel.
    # @param role [Symbol] named pipe-channel role
    # @return [PipeChannel]
    def channel(role)
      @channels.fetch(role)
    end

    # Close channel endpoints that belong only to the guardian/payload side.
    # @return [void]
    def parent_ready
      close_ends(PARENT_CLOSE)
    end

    # Close channel endpoints that belong only to the caller side.
    # @return [void]
    def child_ready
      close_ends(CHILD_CLOSE)
    end

    # Redirect and exec the payload; report an exception class and exit directly with 127 on failure.
    # @param invocation [CommandInvocation] sanitized argv invocation
    # @return [void]
    def payload(invocation)
      channel(:output).redirect_output
      invocation.execute
    rescue StandardError => error
      warn "Child execution refused: #{error.class}"
      ForkBoundary.finish(127)
    end

    # Close every owned channel.
    # @return [void]
    def close
      @channels.each_value(&:close)
    end

    private

    # Close the specified endpoint for each named channel.
    # @param ends [Hash{Symbol => Symbol}] channel names and endpoint close actions
    # @return [void]
    def close_ends(ends)
      ends.each do |role, action|
        endpoint = channel(role)
        case action
        when :close_reader then endpoint.close_reader
        when :close_writer then endpoint.close_writer
        else raise Error, 'Unknown pipe close action'
        end
      end
    end
  end

  # Replaces the payload process with an argv command in a sanitized environment.
  class CommandInvocation
    # Retain argv and explicit child environment/cwd options for exec.
    # @param arguments [Array<String>] argv executable and arguments
    # @param options [Hash{Symbol => Object}] env, chdir, timeout, and optional allow_failure command options
    def initialize(arguments, options)
      @arguments = arguments
      @options = options
    end

    # Exec argv with only the sanitized base and explicit environment, closing unrelated descriptors.
    # @return [void]
    def execute
      exec(SmokeConsumer.environment.merge(@options.fetch(:env, {})), *@arguments,
           chdir: @options.fetch(:chdir, Dir.pwd), unsetenv_others: true, close_others: true)
    end
  end

  # The bounded session anchor outlives the executed/reaped leader and its inherited output.
  # A foreign process cannot join this session from the caller's session.
  class CommandGuardian
    # Run the session guardian and exit directly with 0, or 70 on guardian failure.
    # @param invocation [CommandInvocation] sanitized argv invocation
    # @param pipes [CommandPipes] owned guardian protocol channels
    # @param expiry [Numeric] monotonic expiration time
    # @return [void]
    def self.run(invocation, pipes, expiry)
      new(invocation, pipes, expiry).run
      ForkBoundary.finish(0)
    rescue StandardError
      ForkBoundary.finish(70)
    end

    # Retain invocation, protocol channels, and expiry with no payload status yet.
    # @param invocation [CommandInvocation] sanitized argv invocation
    # @param pipes [CommandPipes] owned guardian protocol channels
    # @param expiry [Numeric] monotonic expiration time
    def initialize(invocation, pipes, expiry)
      @invocation = invocation
      @pipes = pipes
      @expiry = expiry
      @pid = nil
      @status = nil
      @identity = nil
    end

    # Gate payload execution, observe the session, watch completion, and terminate descendants.
    # @return [void]
    def run
      Process.setsid
      @pipes.child_ready
      return unless @pipes.channel(:gate).allow_execution?

      @identity = ProcessCensus.observe.process(Process.pid).group_identity
      @pid = fork { @pipes.payload(@invocation) }
      @pipes.channel(:output).close_writer
      watch
      ProcessTree.stop_members(@identity)
      DirectChild.new(@pid).reap unless @status
    ensure
      @pipes.close
    end

    private

    # Poll payload exit status until cleanup is requested or the deadline expires.
    # @return [void]
    def watch
      loop do
        poll_status
        return if @pipes.channel(:control).cleanup_requested? || SmokeConsumer.clock >= @expiry

        sleep 0.05
      end
    end

    # Publish the first actual wait status exactly once.
    # @return [void]
    def poll_status
      return if @status

      result = Process.waitpid2(@pid, Process::WNOHANG)
      return unless result

      @status = result.last
      @pipes.channel(:status).send_exit(@status)
    end
  end

  # Terminates an observed isolated command group and reaps its direct guardian.
  class CommandGroup
    # Retain the observed group identity, cleanup channel, and directly owned anchor child.
    # @param identity [Hash{String => Object}] expected observed PID/birth identity and optional group/UID fields
    # @param control [PipeChannel] guardian cleanup-control channel
    def initialize(identity, control)
      @identity = identity
      @control = control
      @child = DirectChild.new(identity.fetch('pid'))
    end

    # Stop the isolated process tree and reap the anchor, recovering the guardian on failure.
    # @return [void]
    def terminate
      ProcessTree.stop([@identity])
      @child.reap
    rescue StandardError
      recover_guardian
      raise
    ensure
      @control.close_writer
    end

    private

    # Close control, resume the guardian, and reap it after cleanup failure.
    # @return [void]
    def recover_guardian
      # A direct un-reaped child remains kernel-owned when observation fails.
      @control.close_writer
      @child.resume
      @child.reap
    end
  end

  # Creates a gated session anchor before releasing an observed command group.
  class CommandSpawn
    # Retain the invocation, optional ownership, deadline, and newly allocated channels.
    # @param invocation [CommandInvocation] sanitized argv invocation
    # @param ownership [Ownership, nil] exclusive scope, optional only for standalone commands
    # @param limit [Deadline] shared monotonic operation deadline
    def initialize(invocation, ownership, limit)
      @invocation = invocation
      @ownership = ownership
      @limit = limit
      @pipes = CommandPipes.new
    end

    # Fork the anchor and return its observed group and output/status readers.
    # @return [Array]
    def launch
      pid = start_anchor
      release_group(pid)
    rescue StandardError
      @pipes.close
      DirectChild.new(pid).terminate if pid
      raise
    ensure
      @pipes.channel(:gate).close_writer
    end

    private

    # Wait for the new session group, optionally register ownership, then release execution.
    # @param pid [Integer] process ID to observe, signal, or reap
    # @return [Array]
    def release_group(pid)
      @limit.poll('Command group startup deadline exceeded') { Process.getpgid(pid) == pid && Process.getsid(pid) == pid }
      identity = ProcessCensus.observe.process(pid).group_identity
      @ownership&.register_group(identity)
      group = CommandGroup.new(identity, @pipes.channel(:control))
      @pipes.channel(:gate).send_token
      [group, @pipes.channel(:output).reader, @pipes.channel(:status).reader]
    end

    # Fork the guardian and close child-only endpoints in the caller.
    # @return [Integer]
    def start_anchor
      pid = fork { CommandGuardian.run(@invocation, @pipes, @limit.expires_at + 5) }
      @pipes.parent_ready
      pid
    end
  end

  # Drains a command pipe into a bounded binary buffer without blocking indefinitely.
  class CommandOutput
    attr_reader :text, :reader

    # Retain the owned reader and allocate an empty binary output buffer.
    # @param reader [IO] owned output read endpoint
    def initialize(reader)
      @reader = reader
      @text = +''.b
    end

    # Report whether EOF has closed the output reader.
    # @return [Boolean]
    def complete?
      @reader.closed?
    end

    # Read available bytes without blocking and reject output beyond 16 MiB.
    # @return [void]
    # @raise [Error] output exceeds the bound
    def read_next
      return if complete? || !@reader.wait_readable(0)

      @text << @reader.read_nonblock(16_384)
      raise Error, 'Child output exceeded 16 MiB' if @text.bytesize > 16 * 1024 * 1024
    rescue EOFError
      @reader.close
    rescue IO::WaitReadable
      nil
    end
  end

  # This is the real executed child's exit observation, forwarded through a private pipe.
  class CommandExit
    attr_reader :exitstatus, :termsig

    # Decode the JSON receipt and require exactly one valid exit code or terminating signal.
    # @param text [String] JSON exit-status receipt
    # @raise [Error] exit/signal receipt is malformed
    def initialize(text)
      data = self.class.decode(text)
      @exitstatus, @termsig = data.values_at('exitstatus', 'termsig')
      valid_exit = @exitstatus.is_a?(Integer) && (0..255).cover?(@exitstatus) && !@termsig
      valid_signal = !@exitstatus && @termsig.is_a?(Integer) && @termsig.positive?
      raise Error, 'Malformed actual child exit observation' unless valid_exit || valid_signal

      @success = valid_exit && @exitstatus.zero?
    end

    # Decode the exit/signal JSON, translating invalid JSON to a smoke error.
    # @param text [String] JSON exit-status receipt
    # @return [Object] decoded JSON; field validation belongs to initialization
    # @raise [Error] status JSON is malformed
    def self.decode(text)
      JSON.parse(text)
    rescue JSON::ParserError
      raise Error, 'Malformed actual child exit observation'
    end

    # Report whether the receipt records exit status zero.
    # @return [Boolean]
    def success?
      @success
    end
  end

  # Collects command output and a separate immutable exit-status receipt.
  class CommandChild
    # Allocate separate output/status collectors before any status has been observed.
    # @param reader [IO] owned output read endpoint
    # @param status_reader [IO] separate owned exit-status read endpoint
    def initialize(reader, status_reader)
      @output = CommandOutput.new(reader)
      @status_output = CommandOutput.new(status_reader)
      @status = nil
    end

    # Drain output/status until both EOF and a valid exit receipt are observed.
    # @param limit [Deadline] shared monotonic operation deadline
    # @return [Array(String, CommandExit)]
    def collect(limit)
      until complete?
        limit.check('Operation deadline exceeded')
        wait_for_output
        @output.read_next
        @status_output.read_next
        poll_status
      end
      [@output.text, @status]
    end

    private

    # Wait once for either open channel, without throttling output on an empty status pipe.
    # @return [Array, nil] ready descriptors, or nil when the bounded readiness wait expires
    def wait_for_output
      readers = [@output.reader, @status_output.reader].reject(&:closed?)
      IO.select(readers, nil, nil, 0.05) unless readers.empty?
    end

    # Require an exit receipt and closed output before collection is complete.
    # @return [Boolean, nil] completion state, or nil before status is observed
    def complete?
      @status && @output.complete?
    end

    # Drain the status channel and decode it only after EOF.
    # @return [void]
    def poll_status
      @status = CommandExit.new(@status_output.text) if !@status && @status_output.complete?
    end
  end

  # Runs argv commands under per-call and whole-run deadlines with owned group cleanup.
  class Command
    # Create the whole-run deadline and retain optional process-group ownership.
    # @param timeout [Numeric] whole-run limit in seconds
    # @param ownership [Ownership, nil] exclusive scope, optional only for standalone commands
    # @param ceiling [Numeric] outer monotonic expiration ceiling
    def initialize(timeout: 1800, ownership: nil, ceiling: Float::INFINITY)
      @limit = Deadline.new(timeout, ceiling: ceiling)
      @ownership = ownership
    end

    # Expose the whole-run monotonic expiration time.
    # @return [Numeric]
    def deadline
      @limit.expires_at
    end

    # Capture argv output and require success unless allow_failure is explicitly set.
    # @param arguments [Array<String>] argv executable and arguments
    # @param options [Hash{Symbol => Object}] env, chdir, timeout, and optional allow_failure command options
    # @return [Array(String, CommandExit)]
    def call(*arguments, **options)
      text, status = capture(*arguments, **options)
      CommandStatus.new(arguments.first, status).require_success unless options.fetch(:allow_failure, false)
      [text, status]
    end

    # Launch a gated group, collect under the bounded deadline, and always close/reap it.
    # @param arguments [Array<String>] argv executable and arguments
    # @param options [Hash{Symbol => Object}] env, chdir, timeout, and optional allow_failure command options
    # @return [Array(String, CommandExit)]
    def capture(*arguments, **options)
      @limit.check('Whole consumer smoke deadline exceeded')
      limit = Deadline.new(options.fetch(:timeout, 600), ceiling: deadline)
      invocation = CommandInvocation.new(arguments, options)
      group, reader, status_reader = CommandSpawn.new(invocation, @ownership, limit).launch
      CommandChild.new(reader, status_reader).collect(limit)
    ensure
      reader&.close unless reader&.closed?
      status_reader&.close unless status_reader&.closed?
      group&.terminate
    end
  end
end
