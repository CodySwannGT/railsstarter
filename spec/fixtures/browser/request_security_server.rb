# frozen_string_literal: true

require 'bundler/setup'
require 'json'
require 'fileutils'
require 'digest'

root = ENV.fetch('REQUEST_RATE_ROOT', File.expand_path('../../..', __dir__))
scratch = ENV.fetch('REQUEST_SECURITY_SCRATCH')
owner = JSON.parse(File.read(File.join(scratch, 'owner.json')))
raise 'Request security fixture ownership mismatch' unless owner['token'] == ENV.fetch('REQUEST_SECURITY_TOKEN')

if ENV['REQUEST_RATE_ROOT']
  require_relative '../requests/request_rate_limit_server'
  RateLimitServerOwnership.boot
else
  require File.join(root, 'spec/fixtures/runtime/smoke')
  DependencySmoke.validate_environment!
  DependencySmoke.configure_environment
  DependencySmoke.configure_aws
  require 'mysql2'
  Mysql2::Client.define_singleton_method(:new) { |*| raise 'Request security browser forbids database access' }
  require File.join(root, 'config/environment')
  DependencySmoke.validate_authored_responses!
end

source = File.read(File.join(root, 'app/views/layouts/application.html.erb'))
controls = { 'nonce' => source.sub('<%= javascript_importmap_tags %>', '<%= javascript_importmap_tags.gsub(/ nonce="[^"]+"/, "").html_safe %>') }
%w[css js].each do |kind|
  tag = kind == 'css' ? 'link' : 'script'
  controls[kind] = source.sub(/(<#{tag}[^>]*bootstrap[^>]*integrity="sha384-)(.)/m) do
    "#{Regexp.last_match(1)}#{Regexp.last_match(2) == 'A' ? 'B' : 'A'}"
  end
end
layouts = File.join(scratch, 'views', 'layouts')
FileUtils.mkdir_p(layouts)
controls.each do |name, changed|
  raise 'Negative control did not change source' if changed == source

  File.write(File.join(layouts, "control_#{name}.html.erb"), changed, mode: 'wx', perm: 0o600)
end

class RequestSecurityFixtureController < HomeController
  content_security_policy do |policy|
    if params[:control] == 'cdn'
      policy.script_src :self
      policy.style_src :self
    end
  end

  def index
    flash.now[:notice] = 'Request security acceptance flash'
    case params[:control]
    when 'nonce', 'css', 'js'
      prepend_view_path File.join(ENV.fetch('REQUEST_SECURITY_SCRATCH'), 'views')
      render 'home/index', layout: "control_#{params[:control]}"
    else
      render 'home/index'
    end
  end
end

Rails.application.routes.prepend do
  get '/__request_security' => 'request_security_fixture#index'
  get '/__unauthorized.js', to: ->(_) { [200, { 'content-type' => 'application/javascript' }, ['window.unauthorizedSourceRan = true']] }
  get '/__unauthorized.css', to: ->(_) { [200, { 'content-type' => 'text/css' }, ['body { --unauthorized-source: reached; }']] }
end
Rails.application.reload_routes!

require 'puma'
ports = ENV.fetch('REQUEST_SECURITY_PORTS').split(',').map { |port| Integer(port) }
owner.merge!(pid: Process.pid, cwd: root, ports: ports, aws: DependencySmoke.aws_evidence,
             layout_sha256: Digest::SHA256.hexdigest(source), database_mode: ENV.key?('REQUEST_RATE_ROOT'))
File.write(File.join(scratch, 'server-owner.json'), JSON.pretty_generate(owner), mode: 'wx', perm: 0o600)
server = Puma::Server.new(Rails.application)
ports.each { |port| server.add_tcp_listener('127.0.0.1', port) }
trap('TERM') { server.stop(true) }
server.run.join
