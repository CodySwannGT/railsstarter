# frozen_string_literal: true

require 'json'
require 'socket'

# Copied only into an owned generated consumer's app/jobs; never a production job.
class ConsumerSmokeFixtureJob < ApplicationJob
  queue_as :default

  def perform(token, name)
    raise 'Unexpected smoke job identity' unless token == ENV.fetch('CONSUMER_SMOKE_TOKEN') && name == ENV.fetch('CONSUMER_SMOKE_NAME')

    evidence = File.realpath(ENV.fetch('CONSUMER_SMOKE_EVIDENCE'))
    raise 'Foreign evidence directory' unless evidence == Rails.root.join('tmp/consumer-smoke-evidence').to_s

    marker = File.join(evidence, 'worker-job.json')
    data = { token: token, name: name, job_id: job_id, pid: Process.pid, hostname: Socket.gethostname }
    File.open(marker, File::WRONLY | File::CREAT | File::EXCL | File::NOFOLLOW, 0o600) do |file|
      file.write(JSON.generate(data))
      file.flush
      file.fsync
    end
  end
end
