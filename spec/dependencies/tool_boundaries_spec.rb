# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'
require 'rbconfig'
require 'io/wait'
require_relative '../../test/runtime/dependency_upgrade/resource'

RSpec.context 'when exercising development tool boundaries' do
  # @param group [Integer, Boolean] the exclusive leader or its still-owned group
  # @param termination [String] fixed native behavior exercised by these controls
  # @return [Integer] a direct waitable child, ready after TERM handling is armed
  def ready_tool_child(group, termination)
    reader, writer = IO.pipe
    source = "trap('TERM') { #{termination} }; STDOUT.sync = true; puts 'ready'; sleep"
    pid = Process.spawn(RbConfig.ruby, '-e', source, pgroup: group, out: writer, err: File::NULL)
    writer.close
    raise 'Owned tool child did not become ready' unless reader.wait_readable(5) && reader.gets == "ready\n"
    raise 'Owned tool child group changed' unless Process.getpgid(pid) == (group == true ? pid : group)

    pid
  rescue StandardError
    reap_tool_child(pid)
    raise
  ensure
    reader&.close
    writer&.close unless writer&.closed?
  end

  # Positive direct-child waitability prevents signaling a reused numeric PID.
  # @param pid [Integer, nil] this example's originally spawned direct child
  # @return [void] reap every remaining owned child without adopting another PID
  def reap_tool_child(pid)
    return unless pid && Process.waitpid(pid, Process::WNOHANG).nil?

    Process.kill('KILL', pid)
    Process.waitpid(pid)
  rescue Errno::ECHILD
    # This exact child was already positively reaped; never signal its old PID.
  end

  # @param pid [Integer] the exclusive group leader recorded before shutdown
  # @return [void] require native absence, never a recorded signal as success
  def expect_tool_group_absent(pid)
    expect { Process.kill(0, -pid) }.to raise_error(Errno::ESRCH)
  end

  it 'waits for a delayed native tool group member after its leader is reaped' do
    leader = ready_tool_child(true, 'exit')
    member = ready_tool_child(leader, 'sleep 0.3; exit')
    reaper = Thread.new do
      Process.waitpid(member)
    rescue Errno::ECHILD
      # A failed assertion's ensure can positively reap this same direct child.
    end
    expect(DependencyResource.stop_tool_group!(leader)).to be(true)
    expect(reaper.value).to eq(member)
    expect { Process.waitpid(leader, Process::WNOHANG) }.to raise_error(Errno::ECHILD)
    expect_tool_group_absent(leader)
  ensure
    reap_tool_child(member)
    reaper&.join
    reap_tool_child(leader)
    expect_tool_group_absent(leader) if leader
  end

  it 'refuses a persistent native tool group member without signaling after leader reap' do
    leader = ready_tool_child(true, 'exit')
    member = ready_tool_child(leader, 'nil')
    expect { DependencyResource.stop_tool_group!(leader) }.to raise_error(Timeout::Error)
    expect { Process.waitpid(leader, Process::WNOHANG) }.to raise_error(Errno::ECHILD)
    expect(Process.waitpid(member, Process::WNOHANG)).to be_nil
    expect(Process.kill(0, member)).to eq(1)
  ensure
    reap_tool_child(member)
    reap_tool_child(leader)
    expect_tool_group_absent(leader) if leader
  end

  it 'runs real WebConsole, Kamal configuration and a bounded Thruster proxy' do
    fixture = File.expand_path('../../test/runtime/dependency_upgrade/runner.py', __dir__)
    output, error, status = Open3.capture3('python3', fixture, '--development')
    result = JSON.parse(output.lines.last)
    report = JSON.parse(File.read(result.fetch('report')))
    expect(status.success?).to be(true), "#{output}\n#{error}\n#{report.fetch('error', '')}"
    observed = JSON.parse(report.fetch('boundaries').lines.last)
    expect(observed).to include('web_console' => { 'mounted' => true, 'loopback' => true, 'foreign_rejected' => true },
                                'kamal' => { 'host_parsed' => true, 'synthetic_parsed' => true },
                                'thruster' => include('cache' => true, 'request_limit' => true, 'rails_home' => '200', 'rails_health' => '200',
                                                      'owned_child_reaped' => true, 'proxy_closed' => true, 'backend_closed' => true,
                                                      'process_group_absent' => true))
    expect(report.fetch('cleanup')).to include('container_absent' => true, 'volume_absent' => true, 'children_reaped' => true, 'scratch_absent' => true)
  end
end
