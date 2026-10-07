# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'

RSpec.context 'when exercising development tool boundaries' do
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
                                                      'owned_child_reaped' => true, 'proxy_closed' => true))
    expect(report.fetch('cleanup')).to include('container_absent' => true, 'volume_absent' => true, 'children_reaped' => true, 'scratch_absent' => true)
  end
end
