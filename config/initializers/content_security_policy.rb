# frozen_string_literal: true

require 'securerandom'
require_relative '../../lib/deployed_host_policy'

# Importmap and Turbo use Rails' request nonce; Bootstrap retains its authored SRI.
# https://guides.rubyonrails.org/security.html#content-security-policy-header
Rails.application.configure do
  asset_origin = DeployedHostPolicy.asset_origin
  assets = [:self, asset_origin].compact
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri :self
    policy.object_src :none
    policy.frame_ancestors :none
    policy.form_action :self
    policy.script_src(*assets, 'https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js')
    policy.style_src(*assets, 'https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css')
    policy.img_src(*assets, :data)
    policy.font_src(*assets)
    policy.connect_src(*assets)
  end
  config.content_security_policy_nonce_generator = ->(_) { SecureRandom.base64(24) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
  config.content_security_policy_report_only = false
end
