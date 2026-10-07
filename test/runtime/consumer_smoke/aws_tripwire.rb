# frozen_string_literal: true

# Loaded through RUBYOPT before Rails. Explicit SDK stubs plus reaching terminal/socket guards.
require 'bundler/setup'
require 'json'
require 'socket'
require 'net/http'
require 'aws-sdk-core'
require 'aws-sdk-cloudwatch'

module ConsumerSmokeAws
  class Blocked < StandardError; end

  def self.record(kind, **data)
    path = evidence_path
    File.open(path, File::WRONLY | File::APPEND | File::CREAT | File::NOFOLLOW, 0o600) do |file|
      file.flock(File::LOCK_EX)
      file.puts(JSON.generate({ kind: kind, phase: ENV.fetch('CONSUMER_SMOKE_PHASE'), pid: Process.pid }.merge(data)))
      file.flush
      file.fsync
    end
  end

  def self.evidence_path
    original = ENV.fetch('CONSUMER_SMOKE_EVIDENCE')
    evidence = File.realpath(original)
    expected = File.expand_path('../../../tmp/consumer-smoke-evidence', __dir__)
    raise Blocked, 'Foreign or symlinked AWS evidence root' unless evidence == expected && !File.symlink?(original)
    raise Blocked, 'Malformed smoke token' unless ENV.fetch('CONSUMER_SMOKE_TOKEN').match?(/\A[a-f0-9]{32}\z/)

    File.join(evidence, 'aws.jsonl')
  end

  # Generated clients override Base#build_request; Request is the actual dispatch seam.
  module Requests
    def send_request(*)
      service = context.client.class.name
      stubbed = context.config.stub_responses
      allowed = service == 'Aws::CloudWatch::Client' && stubbed
      ConsumerSmokeAws.record('sdk_request', service: service, operation: context.operation_name, stubbed: stubbed, blocked: !allowed)
      raise Blocked, 'AWS configuration lookup or unstubbed request refused' unless allowed

      super
    end
  end

  module Terminal
    def call(_context)
      ConsumerSmokeAws.record('provider_transport_attempt', blocked: true)
      raise Blocked, 'AWS provider terminal transport refused'
    end
  end

  module Stubbing
    def call(context)
      response = super
      ConsumerSmokeAws.record('stub_handled', service: context.client.class.name, operation: context.operation_name, blocked: false)
      response
    end
  end

  module CredentialLookup
    def initialize(*)
      ConsumerSmokeAws.record('credential_lookup', blocked: true)
      raise Blocked, 'AWS credential lookup refused'
    end
  end

  module Sockets
    # TCPServer inherits this singleton hook but binds a listener, not an outbound socket.
    def new(host, *, **)
      unless self == TCPServer || %w[localhost 127.0.0.1 ::1 db].include?(host.to_s)
        ConsumerSmokeAws.record('socket_attempt', blocked: true)
        raise Blocked, 'External socket refused'
      end
      super
    end
  end

  module SocketTcp
    def tcp(host, *)
      unless %w[localhost 127.0.0.1 ::1 db].include?(host.to_s)
        ConsumerSmokeAws.record('socket_attempt', blocked: true)
        raise Blocked, 'External Socket.tcp refused'
      end
      super
    end
  end

  module Http
    def connect
      unless %w[localhost 127.0.0.1 ::1 db].include?(address)
        ConsumerSmokeAws.record('http_attempt', blocked: true)
        raise Blocked, 'External HTTP refused'
      end
      super
    end
  end
end

Aws.config.update(stub_responses: true, credentials: Aws::Credentials.new('synthetic-smoke', 'synthetic-smoke'), region: 'us-east-1')
Seahorse::Client::Request.prepend(ConsumerSmokeAws::Requests)
Seahorse::Client::NetHttp::Handler.prepend(ConsumerSmokeAws::Terminal)
Aws::Plugins::StubResponses::StubbingHandler.prepend(ConsumerSmokeAws::Stubbing)
%i[InstanceProfileCredentials ECSCredentials SharedCredentials AssumeRoleWebIdentityCredentials].each do |name|
  Aws.const_get(name).prepend(ConsumerSmokeAws::CredentialLookup) if Aws.const_defined?(name)
end
TCPSocket.singleton_class.prepend(ConsumerSmokeAws::Sockets)
Socket.singleton_class.prepend(ConsumerSmokeAws::SocketTcp)
Net::HTTP.prepend(ConsumerSmokeAws::Http)
ConsumerSmokeAws.record('armed', stubbed: true, blocked: false)
