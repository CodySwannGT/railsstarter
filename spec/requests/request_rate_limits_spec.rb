# frozen_string_literal: true

require_relative '../fixtures/requests/request_rate_limit_harness'

RSpec.describe 'Anonymous request quota through actual middleware and HTTP' do
  let(:harness) { RequestRateLimitHarness.new }

  before { harness.start }
  after { harness.stop }

  def payload(response)
    JSON.parse(response.body)
  end

  it 'shares a quota across app processes despite rotating identity headers and separates two socket clients' do
    ports = Array.new(2) { harness.spawn_server }
    responses = Array.new(13) do |number|
      headers = { 'X-Forwarded-For' => "198.51.100.#{number}", 'Forwarded' => "for=198.51.100.#{number}", 'X-Real-IP' => '10.1.2.3', 'Client-IP' => "198.51.100.#{number}",
                  'Authorization' => 'Bearer synthetic-attacker', 'Cookie' => 'session=synthetic-attacker' }
      harness.response(ports[number % 2], '/__quota', headers)
    end
    expect(responses.map(&:code)).to eq((['200'] * 12) + ['429'])
    expect(responses.first(12).map { |response| payload(response).fetch('count') }).to eq((1..12).to_a)
    expect(responses.first(2).map { |response| payload(response).fetch('pid') }.uniq.length).to eq(2)
    expect(responses.last['retry-after'].to_i).to be_between(1, 600)
    expect(payload(harness.response(ports.first, '/__quota', {}, host: '::1')).fetch('ip')).to eq('::1')
  end

  it 'keeps exact health available after a quota and fails closed when the physical counter table is absent' do
    port = harness.spawn_server('REQUEST_RATE_LIMIT' => '1')
    expect([harness.response(port).code, harness.response(port).code]).to eq(%w[200 429])
    expect(harness.response(port, '/up?query=1').code).to eq('200')
    harness.command('down')
    expect(harness.response(port).code).to eq('503')
    expect(harness.response(port, '/up').code).to eq('200')
    expect(harness.response(port, '/up/').code).to eq('503')
    harness.command('up')
  end

  it 'uses real pinned Thruster append behavior and rejects missing or untrusted direct topology' do
    front, port = harness.spawn_thruster('REQUEST_INGRESS_PROFILE' => 'thruster', 'THRUSTER_TRUSTED_PEERS' => '::1/128')
    response = harness.response(front, '/__quota', { 'X-Forwarded-For' => 'spoof, 10.9.8.7' })
    expect(payload(response).fetch('ip')).to eq('127.0.0.1')
    expect(payload(response).dig('headers', 'HTTP_X_FORWARDED_FOR')).to end_with('127.0.0.1')
    expect(harness.response(port, '/__quota', {}, host: '::1').code).to eq('400')
    expect(harness.response(port, '/__quota', { 'X-Forwarded-For' => '10.9.8.7' }).code).to eq('403')
  end

  it 'uses the actual local ALB append model and refuses malformed client suffixes and wrong immediate peers' do
    port = harness.spawn_server('REQUEST_INGRESS_PROFILE' => 'alb', 'ALB_TRUSTED_PEERS' => '::1/128')
    front = harness.spawn_alb(port)
    response = harness.response(front, '/__quota', { 'X-Forwarded-For' => 'spoof, 10.9.8.7' }, host: '::1')
    expect(payload(response).fetch('ip')).to eq('::1')
    expect(harness.response(port, '/__quota', { 'X-Forwarded-For' => '::1' }).code).to eq('403')
    expect(harness.response(port, '/__quota', { 'X-Forwarded-For' => '[::1]:65536' }, host: '::1').code).to eq('400')
    expect(harness.response(port, '/__quota', { 'X-Forwarded-For' => '10.9.8.7:1234' }, host: '::1').code).to eq('200')
  end

  it 'checks the ALB hop behind real Thruster and ignores attacker-controlled earlier prefixes' do
    thruster, port = harness.spawn_thruster('REQUEST_INGRESS_PROFILE' => 'alb_thruster', 'THRUSTER_TRUSTED_PEERS' => '::1/128', 'ALB_TRUSTED_PEERS' => '::1/128')
    front = harness.spawn_alb(thruster)
    response = harness.response(front, '/__quota', { 'X-Forwarded-For' => 'spoof, 10.9.8.7' }, host: '::1')
    expect(payload(response).fetch('ip')).to eq('::1')
    expect(harness.response(thruster, '/__quota', { 'X-Forwarded-For' => '10.9.8.7' }).code).to eq('403')
    expect(harness.response(port, '/__quota', { 'X-Forwarded-For' => '::1' }, host: '::1').code).to eq('400')
  end

  it 'starts a new fixed window naturally while preserving the previous physical bucket' do
    port = harness.spawn_server('REQUEST_RATE_LIMIT' => '1', 'REQUEST_RATE_PERIOD' => '2')
    raise 'Window alignment timeout' unless RequestSecurityDeadline.wait(3) { Time.now.to_f % 2 < 0.5 }

    expect([harness.response(port).code, harness.response(port).code]).to eq(%w[200 429])
    initial = harness.command('audit').fetch('rows')
    raise 'Window expiry timeout' unless RequestSecurityDeadline.wait(4) { Time.now.to_i >= initial.first.fetch('expires_at') }

    response = harness.response(port)
    expect([response.code, payload(response).fetch('count')]).to eq(['200', 1])
    expect(harness.command('audit').fetch('rows')).to include(initial.first)
  end

  it 'returns a controlled 503 on a real owned database disconnect without losing health liveness' do
    port = harness.spawn_server
    expect(harness.response(port).code).to eq('200')
    harness.database.stop
    expect(harness.response(port).code).to eq('503')
    expect(harness.response(port, '/up').code).to eq('200')
    expect(harness.database.cleanup).to include(container_absent: true, volume_absent: true, port_closed: true)
  end
end
