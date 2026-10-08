# frozen_string_literal: true

# Owned, database-free browser fixture. Renders the real app, never copied assets.
require 'json'
require 'digest'
require 'bundler/setup'

root = File.expand_path('../../..', __dir__)
scratch = ENV.fetch('BOOTSTRAP_BROWSER_SCRATCH')
owner = JSON.parse(File.read(File.join(scratch, 'owner.json')))
raise 'Browser fixture ownership mismatch' unless owner.fetch('token') == ENV.fetch('BOOTSTRAP_BROWSER_TOKEN')

require File.join(root, 'spec/fixtures/runtime/smoke')
DependencySmoke.validate_environment!
DependencySmoke.configure_environment
DependencySmoke.configure_aws

require 'mysql2'
module BootstrapBrowserNoDatabase
  def new(*)
    raise 'Bootstrap browser journey forbids database connections'
  end
end
Mysql2::Client.singleton_class.prepend(BootstrapBrowserNoDatabase)

require File.join(root, 'config/environment')
DependencySmoke.validate_authored_responses!

# Only negative controls copy the real layout, changing exactly one SRI character.
source = File.binread(File.join(root, 'app/views/layouts/application.html.erb'))
controls = {}
%w[css js].each do |kind|
  tag = kind == 'css' ? 'link' : 'script'
  pattern = /(<#{tag}[^>]*bootstrap[^>]*integrity="sha384-)(.)/m
  raise "Missing #{kind} source integrity" unless source.match?(pattern)

  changed = source.sub(pattern) { "#{Regexp.last_match(1)}#{Regexp.last_match(2) == 'A' ? 'B' : 'A'}" }
  raise 'Control must change exactly one source byte' unless source.bytes.zip(changed.bytes).one? { |a, b| a != b }

  file = File.join(scratch, 'views', 'layouts', "control_#{kind}.html.erb")
  File.binwrite(file, changed, mode: 'wx', perm: 0o600)
  controls[kind] = { sha256: Digest::SHA256.hexdigest(changed), source_sha256: Digest::SHA256.hexdigest(source) }
end

class BootstrapBrowserFixtureController < HomeController
  def index
    flash.now[:notice] = 'Bootstrap acceptance flash'
    if %w[css js].include?(params[:control])
      prepend_view_path File.join(ENV.fetch('BOOTSTRAP_BROWSER_SCRATCH'), 'views')
      render 'home/index', layout: "control_#{params[:control]}"
    else
      render 'home/index'
    end
  end
end

Rails.application.routes.prepend do
  get '/__bootstrap_acceptance' => 'bootstrap_browser_fixture#index'
end
Rails.application.reload_routes!

require 'puma'
port = Integer(ENV.fetch('BOOTSTRAP_BROWSER_PORT'))
owner.merge!('pid' => Process.pid, 'cwd' => root, 'port' => port, 'controls' => controls,
             'aws' => DependencySmoke.aws_evidence, 'database_mode' => false)
File.write(File.join(scratch, 'server-owner.json'), JSON.pretty_generate(owner), mode: 'wx', perm: 0o600)
server = Puma::Server.new(Rails.application)
server.add_tcp_listener('127.0.0.1', port)
trap('TERM') { server.stop(true) }
trap('INT') { server.stop(true) }
server.run.join
