# frozen_string_literal: true

require Rails.root.join('lib/request_policy')
require Rails.root.join('lib/request_rate_limit_store')
require Rails.root.join('lib/middleware/trusted_client_ip')

policy = RequestPolicy.new(ENV, environment: Rails.env.to_s)
Rails.application.config.x.request_policy = policy
Rack::Attack.enabled = policy.enabled?
Rack::Attack.cache.store = RequestRateLimitStore.new(namespace: Rails.env.to_s)
Rack::Attack.throttle('anonymous/ip', limit: policy.limit, period: policy.period) do |request|
  request.env.fetch('request_policy.client_ip') unless request.env.fetch('request_policy.health')
end
Rack::Attack.throttled_responder = lambda do |request|
  data = request.env.fetch('rack.attack.match_data')
  retry_after = data.fetch(:period) - (data.fetch(:epoch_time) % data.fetch(:period))
  [429, { 'content-type' => 'application/json', 'cache-control' => 'no-store', 'retry-after' => retry_after.to_s },
   [JSON.generate(error: 'anonymous_request_limit_exceeded')]]
end
Rails.application.config.middleware.move_before(ActionDispatch::RemoteIp, Rack::Attack)
Rails.application.config.middleware.insert_before(ActionDispatch::RemoteIp, Middleware::TrustedClientIp, policy)
