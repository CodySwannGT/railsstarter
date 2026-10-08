# frozen_string_literal: true

# WebConsole is booted in real development mode on separately owned test
# schemas. Thruster wraps real Puma. Nothing changes the deployed topology.
require_relative 'resource'
require_relative 'sdk_boundary'
require 'digest'
require 'net/http'
require 'socket'
require 'timeout'
require 'rbconfig'

resource = DependencyResource.validate!
physical = DependencyResource.physical!(resource)
raise 'Development resource required' unless resource.fetch('environment') == 'development'

Aws.config.update(stub_responses: true, region: 'us-east-1', credentials: Aws::Credentials.new('synthetic', 'synthetic'))
require File.join(DependencyResource::ROOT, 'config/environment')
raise 'WebConsole middleware not mounted in actual development boot' unless Rails.application.middleware.any? { |item| item.klass == WebConsole::Middleware }

if ARGV.first == 'backend'
  require 'puma'
  count = 0
  app = lambda do |env|
    if env.fetch('PATH_INFO') == '/asset.css'
      count += 1
      [200, { 'content-type' => 'text/css; charset=utf-8', 'cache-control' => 'public, max-age=3600',
              'x-owned-backend-count' => count.to_s }, ['body { color: green; }' * 100]]
    else
      Rails.application.call(env)
    end
  end
  server = Puma::Server.new(app)
  server.add_tcp_listener('127.0.0.1', Integer(ENV.fetch('PORT')))
  trap('TERM') { server.stop }
  server.run.join
  exit 0
end

# @return [Integer] a fresh loopback listener port for an owned process
def loopback_port
  TCPServer.open('127.0.0.1', 0) { |socket| socket.addr[1] }
end

application = lambda do |_env|
  Thread.current[:__web_console_binding] = binding
  [200, { 'content-type' => 'text/html; charset=utf-8' }, ['<html><body>synthetic console</body></html>']]
end
middleware = WebConsole::Middleware.new(application)
loopback = Rack::MockRequest.new(middleware).get('/', 'REMOTE_ADDR' => '127.0.0.1')
foreign = Rack::MockRequest.new(middleware).get('/', 'REMOTE_ADDR' => '203.0.113.80')
raise 'Loopback console was not injected' unless loopback.headers['x-web-console-session-id'] && loopback.body.include?('console')
raise 'Foreign console was injected' if foreign.headers['x-web-console-session-id']
raise 'Console fiber state leaked' if Thread.current[:__web_console_binding]

require 'kamal'
host = Kamal::Configuration.create_from(config_file: Pathname.new(File.join(DependencyResource::ROOT, 'config/deploy.yml')), version: 'synthetic-80')
configuration = Kamal::Configuration.create_from(config_file: Pathname.new(File.join(__dir__, 'kamal.yml')), version: 'synthetic-80')
raise 'Host Kamal config did not parse' unless host.service == 'your-project'
raise 'Synthetic Kamal config changed' unless configuration.servers.roles.flat_map(&:hosts) == ['127.0.0.1'] && configuration.registry.password == 'synthetic'

proxy_port = loopback_port
backend_port = loopback_port
scratch = resource.fetch('scratch')
environment = ENV.to_h.reject { |key, _| key.start_with?('THRUSTER_', 'TLS_', 'ACME_', 'EAB_') }
environment.merge!('THRUSTER_HTTP_PORT' => proxy_port.to_s, 'THRUSTER_TARGET_PORT' => backend_port.to_s,
                   'THRUSTER_HTTPS_PORT' => '0', 'THRUSTER_STORAGE_PATH' => File.join(scratch, 'thruster'),
                   'THRUSTER_MAX_REQUEST_BODY' => '32')
trap('TERM') { raise Interrupt, 'Owned tool boundary interrupted' }
pid = Process.spawn(environment, RbConfig.ruby, '-S', 'bundle', 'exec', 'thrust',
                    RbConfig.ruby, '-rbundler/setup', __FILE__, 'backend',
                    pgroup: true, out: File.join(scratch, 'proxy.log'), err: [:child, :out])
begin
  uri = URI("http://127.0.0.1:#{proxy_port}")
  Timeout.timeout(30) do
    loop do
      begin
        break if Net::HTTP.get_response(URI.join(uri.to_s, '/asset.css')).code == '200'
      rescue Errno::ECONNREFUSED
        raise File.read(File.join(scratch, 'proxy.log')) if Process.waitpid(pid, Process::WNOHANG)
      end
      sleep 0.05
    end
  end
  first = Net::HTTP.get_response(URI.join(uri.to_s, '/asset.css'))
  second = Net::HTTP.get_response(URI.join(uri.to_s, '/asset.css'))
  raise 'Real Thruster asset caching failed' unless first.code == '200' && first.body == second.body && second['x-owned-backend-count'] == '1'

  home = Net::HTTP.get_response(URI.join(uri.to_s, '/'))
  health = Net::HTTP.get_response(URI.join(uri.to_s, '/up'))
  raise 'Real Rails home through Thruster failed' unless home.code == '200' && home['content-type'].include?('text/html') &&
                                                         home.body.include?('Welcome to Your Project') && home.body.include?('navbar-navigation')
  raise 'Real Rails health through Thruster failed' unless health.code == '200'

  rejection = Net::HTTP.post(URI.join(uri.to_s, '/'), 'x' * 64)
  raise 'Real Thruster request-size limit missed' unless rejection.code == '413'
rescue StandardError => error
  raise "#{error.class}: #{error.message}\n#{File.read(File.join(scratch, 'proxy.log'))}"
ensure
  group_absent = DependencyResource.stop_tool_group!(pid)
end
closed_ports = [proxy_port, backend_port].map do |port|
  TCPSocket.open('127.0.0.1', port).close
  raise 'Owned tool port remained open'
rescue Errno::ECONNREFUSED
  true
end
puts JSON.generate(physical: physical, web_console: { mounted: true, loopback: true, foreign_rejected: true },
                   kamal: { host_parsed: true, synthetic_parsed: true },
                   thruster: { cache: true, request_limit: true, owned_child_reaped: true,
                               rails_home: home.code, rails_health: health.code,
                               proxy_closed: closed_ports.first, backend_closed: closed_ports.last,
                               process_group_absent: group_absent })
