# frozen_string_literal: true

require 'capybara/rspec'
require_relative '../fixtures/requests/request_rate_limit_harness'

Capybara.threadsafe = true

RSpec.describe 'RequestRateLimits' do
  let(:database) { RequestRateLimitHarness.new }
  let(:settings) { { 'REQUEST_RATE_LIMIT_ENABLED' => 'true', 'REQUEST_RATE_LIMIT' => '120', 'REQUEST_RATE_PERIOD' => '60' } }
  let(:harness) { RequestSecurity.new(throttle_environment: database.environment(settings)) }
  let(:page) { harness.page }

  around do |example|
    database.start
    harness.start
    example.run
  ensure
    begin
      harness.capture('failure') if example.exception && harness.page
    ensure
      begin
        harness.stop
      ensure
        database.stop
      end
    end
  end

  def initialized
    Selenium::WebDriver::Wait.new(timeout: 10).until { page.evaluate_script('!!window.Stimulus && !!window.Turbo') }
  end

  def navigate
    page.find('button[aria-label="Toggle navigation"]').click
    expect(page).to have_css('#navbar-navigation.show', visible: :visible)
    page.find('button[aria-label="Close"]').click
    expect(page).to have_no_css('#flash-messages .alert', visible: :all)
    turbo_navigation
  end

  def turbo_navigation
    page.execute_script('window.quotaDocumentIdentity = "same-document"; Turbo.setProgressBarDelay(0)')
    page.find('#navbar-navigation a', text: 'Home').click
    expect(page).to have_current_path('/')
    initialized
    expect(page.evaluate_script('window.quotaDocumentIdentity')).to eq('same-document')
  end

  it('preserves nonces, required resources and navbar flash Turbo navigation with the physical quota enabled') do
    page.visit('/__request_security')
    initialized
    expect(page.evaluate_script('!!document.querySelector("link[href*=bootstrap]").sheet && bootstrap.Collapse.VERSION === "5.3.8"')).to be(true)
    navigate
    expect(harness.violations).to eq([])
    expect(harness.errors).to eq([])
    health = page.evaluate_async_script("fetch('/up?query=1', {headers: {'Accept':'application/json'}}).then(r => arguments[0](r.status))")
    expect(health).to eq(200)
    expect(database.command('audit').fetch('rows').sum { |row| row.fetch('count') }).to be_positive
    harness.capture('quota-positive')
  end

  it('enforces the existing missing-importmap-nonce failure control with the physical quota enabled') do
    page.visit('/__request_security?control=nonce')
    Selenium::WebDriver::Wait.new(timeout: 10).until { harness.violations.any? { |event| event['directive'] == 'script-src-elem' } }
    expect(page.evaluate_script('!!window.Stimulus || !!window.Turbo')).to be(false)
    expect(harness.violations.all? { |event| event.fetch('disposition') == 'enforce' }).to be(true)
    expect(database.command('audit').fetch('rows').sum { |row| row.fetch('count') }).to be_positive
    harness.capture('quota-nonce-control')
  end

  context 'with a short test quota' do
    let(:settings) { { 'REQUEST_RATE_LIMIT_ENABLED' => 'true', 'REQUEST_RATE_LIMIT' => '20', 'REQUEST_RATE_PERIOD' => '600' } }

    def browser_quota
      page.evaluate_async_script(<<~JS)
        const done = arguments[0];
        (async () => {
          const statuses = [];
          for (let i = 0; i < 21; i++) statuses.push((await fetch('/__request_security')).status);
          const health = await fetch('/up?query=1', {headers: {'Accept':'application/json'}});
          done({statuses, health: health.status});
        })();
      JS
    end

    it('observes real HTTP quota rejection in Chrome while exact health remains available') do
      page.visit('/__request_security')
      initialized
      statuses = browser_quota
      expect(statuses.fetch('statuses')).to include(200, 429)
      expect(statuses.fetch('statuses').last).to eq(429)
      expect(statuses.fetch('health')).to eq(200)
      harness.capture('quota-established-429')
    end
  end
end
