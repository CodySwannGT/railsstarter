# frozen_string_literal: true

require 'timeout'

# Own one unreaped direct leader; observation never grants new signal authority.
class DependencyToolShutdown
  # @param pid [Integer] this invocation's originally spawned waitable leader
  # @param native [Module] existing native group signal and absence operations
  def initialize(pid, native)
    @pid = pid
    @native = native
    @reaped = false
    @killed = false
    @observation_error = nil
  end

  # @return [Boolean] positive reap and native absence inside the original bound
  def stop
    @deadline = clock + 10
    @native.signal_tool_group(@pid, 'TERM')
    loop do
      require_time!
      reap
      absent = @reaped && group_absent?
      remaining = require_time!
      return true if absent

      escalate if remaining <= 5
      sleep [0.01, remaining].min
    end
  end

  private

  # @return [void] only a positive original wait records reaping; ECHILD refuses
  def reap
    return if @reaped

    @reaped = Process.waitpid(@pid, Process::WNOHANG) == @pid
  end

  # @return [void] recheck direct waitability before the sole KILL, never after reap
  def escalate
    return if @reaped || @killed

    reap
    return if @reaped

    @native.signal_tool_group(@pid, 'KILL')
    @killed = true
  end

  # @return [Boolean] denied observations require a later genuine native ESRCH
  def group_absent?
    @native.tool_group_absent?(@pid)
  rescue Errno::EPERM => error
    @observation_error = error
    false
  end

  # @return [Float] check before and after observation, retaining a denied cause
  def require_time!
    remaining = @deadline - clock
    raise Timeout::Error, 'Owned tool group absence was not proved', cause: @observation_error unless remaining.positive?

    remaining
  end

  # @return [Float] one monotonic budget covers TERM, KILL, reap and observation
  def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
