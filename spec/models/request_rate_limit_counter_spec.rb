# frozen_string_literal: true

require_relative '../fixtures/requests/request_rate_limit_harness'

RSpec.describe 'RequestRateLimitCounter' do
  let(:harness) { RequestRateLimitHarness.new }

  after { harness.stop }

  it 'migrates only the owned cache schema and uses an independent cache connection' do
    harness.start
    result = harness.command('audit')
    expect(result.dig('cache', 'database')).to end_with('_cache_test')
    expect(result.dig('primary', 'counter_table')).to be(false)
    expect(result.dig('cache', 'indexes')).to include('columns' => ['counter_key'], 'unique' => true)
    expect(result.fetch('rows')).to be_empty
  end

  it 'serializes cold and hot buckets across two real processes under both supported isolations' do
    harness.start
    %w[read_committed repeatable_read].each do |isolation|
      key = "#{harness.token}/#{isolation}"
      cold = harness.concurrent(key, isolation)
      hot = harness.concurrent(key, isolation)
      expect(cold.flat_map { |item| item.fetch('counts') }.sort).to eq((1..8).to_a)
      expect(hot.flat_map { |item| item.fetch('counts') }.sort).to eq((9..16).to_a)
      expect(cold.map { |item| item.fetch('pid') }.uniq.length).to eq(2)
      expect(hot.first.dig('audit', 'cache', 'isolation')).to eq(isolation.upcase.tr('_', '-'))
    end
  end

  it 'keeps its first expiry fixed and refuses expired increments without a reset' do
    harness.start
    result = harness.command('expiration', 'REQUEST_RATE_KEY' => "#{harness.token}/expiry")
    expect(result.dig('first', 'expires_at')).to eq(result.dig('second', 'expires_at'))
    expect(result.dig('second', 'count')).to eq(2)
    expect(result.fetch('failure')).to eq('Expired counter bucket')
    expect(result.fetch('expired_count')).to eq(2)
  end
end
