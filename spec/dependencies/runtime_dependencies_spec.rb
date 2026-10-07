# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'
require_relative '../../test/runtime/dependency_upgrade/resource'

RSpec.context 'when exercising owned dependency runtime' do
  def runtime_probe
    fixture = File.expand_path('../../test/runtime/dependency_upgrade/runner.py', __dir__)
    output, error, status = Open3.capture3('python3', fixture)
    result = JSON.parse(output.lines.last)
    [output, error, status, JSON.parse(File.read(result.fetch('report')))]
  end

  it 'preserves real queue/cache/cable boundaries and rejects unsafe endpoints with positive cleanup' do
    output, error, status, report = runtime_probe
    expect(status.success?).to be(true), "#{output}\n#{error}\n#{report.fetch('error', '')}"
    expect(report.fetch('rejection_controls').map { |control| control.fetch('rejected') }).to eq([true] * 9)
    expect(report.fetch('cleanup')).to include('container_absent' => true, 'volume_absent' => true,
                                               'scratch_absent' => true, 'children_reaped' => true)
    runtime = JSON.parse(report.fetch('runtime').lines.last)
    expect(runtime).to include(
      'cable_delivery' => true, 'cache_preserved' => true, 'queue_processes_stopped' => true,
      'blocked_ids' => contain_exactly(an_instance_of(Integer)), 'claimed_ids' => contain_exactly(an_instance_of(Integer)),
      'cli_exit' => 0, 'cli_group_absent' => true,
      'cli_processes' => contain_exactly(include('kind' => 'Supervisor(async)'), include('kind' => 'Dispatcher'), include('kind' => 'Worker')),
      'requests' => [include('status' => 200), include('status' => 200)],
      'jbuilder' => { 'payload' => 'café 😀', 'numbers' => [1, 2] }
    )
  end
end
