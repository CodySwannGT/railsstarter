# frozen_string_literal: true

require 'aws-sdk-ssm'
require 'seahorse/client/net_http/handler'

# Observe the actual HTTP terminal handler, after SDK response stubs have exited.
# Request#send_request also handles native stubs and is deliberately left alone.
module DependencySdkBoundary
  class TransportForbidden < StandardError; end

  # @return [void] prevent terminal HTTP, while allowing real stub serialization
  def call(context)
    raise DependencySdkBoundary::TransportForbidden, "Terminal SDK HTTP forbidden: #{context.operation_name}"
  end
end

Seahorse::Client::NetHttp::Handler.prepend(DependencySdkBoundary)
