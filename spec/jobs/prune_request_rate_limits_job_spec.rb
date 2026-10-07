# frozen_string_literal: true

require_relative '../fixtures/requests/request_rate_limit_harness'

RSpec.describe 'PruneRequestRateLimitsJob' do
  let(:harness) { RequestRateLimitHarness.new }

  after { harness.stop }

  it 'prunes only expired security rows while general cache pressure and clear preserve active counters' do
    harness.start
    key = "#{harness.token}/active"
    harness.command('increment', 'REQUEST_RATE_KEY' => key, 'REQUEST_RATE_OPERATIONS' => '3')
    result = harness.command('housekeeping', 'REQUEST_RATE_KEY' => key, 'REQUEST_RATE_CACHE_ESTIMATE' => 'true')
    expect(result.fetch('pressure')).to eq('class' => 'SolidCache::Store', 'entries_before' => 10, 'entries_after' => 0)
    expect(result.fetch('after')).to eq(result.fetch('before'))
    expect(result.fetch('after').fetch('count')).to eq(3)
    expect(result.fetch('pruning')).to eq('first' => 1000, 'remaining' => 1, 'second' => 1, 'expired_absent' => true)
    expect(result.dig('audit', 'primary', 'counter_table')).to be(false)
  end
end
