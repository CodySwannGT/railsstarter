#!/usr/bin/env ruby
# frozen_string_literal: true

# Recorded ECS CLI protocol: text task/container discovery, then session output.
require 'json'
File.open(ENV.fetch('SCHEMA_CLI_LOG'), 'a') { |file| file.puts(JSON.generate(ARGV)) }
case ARGV[0, 2]
when %w[ecs list-tasks]
  $stdout.puts ENV.fetch('SCHEMA_TASK', 'arn:aws:ecs:us-west-2:123456789012:task/fixture/task-123')
when %w[ecs describe-tasks]
  $stdout.puts ENV.fetch('SCHEMA_CONTAINER', 'renamed-app')
when %w[ecs execute-command]
  $stdout.puts 'Starting session with SessionId: fixture'
  $stdout.puts ENV.fetch('SCHEMA_RESPONSE', '{"status":"pass","expected_count":0,"actual_count":0}')
else
  abort 'Unexpected AWS CLI operation'
end
