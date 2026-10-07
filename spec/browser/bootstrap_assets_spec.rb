# frozen_string_literal: true

require 'spec_helper'
require 'capybara/rspec'
require_relative '../fixtures/browser/bootstrap_harness'

Capybara.threadsafe = true

RSpec.describe BootstrapAssets do
  let(:harness) { described_class.new }
  let(:page) { harness.page }

  around do |example|
    harness.start
    example.run
  ensure
    harness.stop
  end

  def visit_fixture(control = nil)
    control ||= ENV.fetch('BOOTSTRAP_BROWSER_CONTROL', nil)
    raise 'Unknown falsification control' if control && !control.match?(/\A(?:css|js)\z/)

    path = '/__bootstrap_acceptance'
    path += "?control=#{control}" if control
    page.visit(path)
    wait_for { page.evaluate_script('!!window.Stimulus && !!window.Turbo') }
  end

  def wait_for(&)
    Selenium::WebDriver::Wait.new(timeout: 10).until(&)
  end

  def browser_errors
    page.driver.browser.logs.get(:browser).select { |entry| entry.level == 'SEVERE' }.map(&:message)
  end

  def expect_loaded_styles
    expect(page.evaluate_script('!!document.querySelector("link[href*=bootstrap]").sheet')).to be(true), 'Source Bootstrap stylesheet was blocked'
    expect(page.evaluate_script('getComputedStyle(document.querySelector("nav")).display')).to eq('flex')
    expect(page.evaluate_script('getComputedStyle(document.querySelector(".alert")).backgroundColor')).to eq('rgb(209, 231, 221)')
  end

  def expect_loaded_script
    expect(page.evaluate_script('!!window.bootstrap')).to be(true), 'Source Bootstrap JavaScript was blocked'
    version = page.find('link[href*="bootstrap"]', visible: :all)[:href].match(%r{bootstrap@([^/]+)})[1]
    expect(page.evaluate_script('bootstrap.Collapse.VERSION')).to eq(version)
  end

  def expect_source_identity
    css = page.find('link[href*="bootstrap"]', visible: :all)
    script = page.find('script[src*="bootstrap"]', visible: :all)
    expect(harness.source).to include(css[:href], css[:integrity], script[:src], script[:integrity])
    expect([css[:crossorigin], script[:crossorigin]]).to eq(%w[anonymous anonymous])
  end

  def expect_navigation_and_flash
    expect(page).to have_css('#navbar-navigation', visible: :hidden)
    page.find('button[aria-label="Toggle navigation"]').click
    expect(page).to have_css('#navbar-navigation.show', visible: :visible)
    expect(page.find('button[aria-label="Toggle navigation"]')[:'aria-expanded']).to eq('true')
    page.find('button[aria-label="Close"]').click
    expect(page).to have_no_css('#flash-messages .alert', visible: :all)
  end

  it('loads source CDN assets and expands navigation, dismisses flash and initializes importmap') do
    visit_fixture
    expect_loaded_styles
    expect_loaded_script
    expect_source_identity
    expect_navigation_and_flash
    page.find('#navbar-navigation a', text: 'Home').click
    expect(page).to have_current_path('/')
    wait_for { page.evaluate_script('!!window.Stimulus && !!window.Turbo') }
    expect(browser_errors).to be_empty
  end

  it('blocks a corrupt stylesheet integrity while unrelated importmap initializes') do
    visit_fixture('css')
    expect(page.evaluate_script('!!document.querySelector("link[href*=bootstrap]").sheet')).to be(false)
    expect(page.evaluate_script('getComputedStyle(document.querySelector("nav")).display')).to eq('block')
    expect(page.evaluate_script('getComputedStyle(document.querySelector(".alert")).backgroundColor')).to eq('rgba(0, 0, 0, 0)')
    expect(browser_errors.join("\n")).to match(/integrity.*bootstrap|bootstrap.*integrity/i)
  end

  it('blocks corrupt script integrity and cannot expand navigation or dismiss flash') do
    visit_fixture('js')
    expect(page.evaluate_script('!!document.querySelector("link[href*=bootstrap]").sheet')).to be(true)
    expect(page.evaluate_script('typeof window.bootstrap')).to eq('undefined')
    page.find('button[aria-label="Toggle navigation"]').click
    expect(page.find('button[aria-label="Toggle navigation"]')[:'aria-expanded']).to eq('false')
    page.find('button[aria-label="Close"]').click
    expect(page).to have_css('#flash-messages .alert', count: 1)
    expect(browser_errors.join("\n")).to match(/integrity.*bootstrap|bootstrap.*integrity/i)
  end
end
