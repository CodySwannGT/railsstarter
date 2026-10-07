# frozen_string_literal: true

require 'spec_helper'
require_relative '../fixtures/browser/request_security_harness'
require_relative '../fixtures/browser/bootstrap_harness'

RSpec.describe BrowserStartupDiagnostics do
  let(:directory) { Dir.mktmpdir('browser-diagnostics-spec-') }
  let(:services) { [] }
  let(:original_error) { Selenium::WebDriver::Error::SessionNotCreatedError.new('fixture startup refusal') }
  let(:config) { instance_double(Capybara::SessionConfig) }
  let(:driver) { instance_double(Capybara::Selenium::Driver) }
  let(:session) { instance_double(Capybara::Session, config: config, driver: driver) }

  around do |example|
    previous = ENV.fetch('BROWSER_STARTUP_ARTIFACT_DIR', nil)
    ENV['BROWSER_STARTUP_ARTIFACT_DIR'] = File.join(directory, 'retained')
    example.run
  ensure
    ENV['BROWSER_STARTUP_ARTIFACT_DIR'] = previous
    FileUtils.remove_entry_secure(directory)
  end

  before do
    allow(config).to receive(:default_max_wait_time=)
    allow(config).to receive(:app_host=)
    allow(Capybara::Session).to receive(:new).and_return(session)
    allow(driver).to receive(:browser) do
      services.last.log&.write("[123:ERROR:startup.cc:1] fixture native startup refusal\n")
      raise original_error
    end
    allow(Selenium::WebDriver::Service).to receive(:chrome).and_wrap_original do |original, **options|
      services << original.call(**options)
      services.last
    end
  end

  def prepared_fixture(type)
    fixture = type.new
    scratch = File.join(directory, type.name)
    Dir.mkdir(scratch, 0o700)
    fixture.instance_variable_set(:@scratch, scratch)
    fixture.instance_variable_set(:@token, SecureRandom.hex(16))
    fixture.instance_variable_set(:@origin, 'http://127.0.0.1:1')
    fixture.instance_variable_set(:@port, 1)
    fixture.instance_variable_set(:@driver_binary, '/fixture/chromedriver')
    fixture.instance_variable_set(:@chrome_binary, '/fixture/chrome')
    fixture
  end

  [RequestSecurity, BootstrapAssets].each do |type|
    context "with #{type.name}" do
      it('retains startup failure diagnostics through a private verbose IO without replacing the exception') do
        fixture = prepared_fixture(type)
        expect { fixture.__send__(:start_browser) }.to raise_error(original_error) { |caught| expect(caught).to equal(original_error) }
        expect(services.last.args).to include('--verbose')
        records = Dir.glob(File.join(ENV.fetch('BROWSER_STARTUP_ARTIFACT_DIR'), '*', 'startup.json'))
        expect(records.length).to eq(1)
        expect(JSON.parse(File.read(records.first))).to include('error_class' => original_error.class.name)
      end
    end
  end

  context 'with owned diagnostic files' do
    let(:diagnostics) { described_class.new(directory, 'fixture') }

    it('retains an empty startup log when failure precedes driver execution') do
      diagnostics.retain(original_error)
      records = Dir.glob(File.join(ENV.fetch('BROWSER_STARTUP_ARTIFACT_DIR'), '*', 'startup.json'))
      expect(records.length).to eq(1)
      expect(JSON.parse(File.read(records.first))).to include('captured_bytes' => 0, 'error_class' => original_error.class.name)
    end

    it('bounds retained startup output and preserves private file and directory permissions') do
      diagnostics.service.log.write('x' * (BrowserStartupDiagnostics::LOG_BYTES + 1))
      diagnostics.retain(original_error)
      retained = Dir.glob(File.join(ENV.fetch('BROWSER_STARTUP_ARTIFACT_DIR'), '*')).fetch(0)
      files = Dir.children(retained).map { |name| File.join(retained, name) }
      expect(File.stat(retained).mode & 0o777).to eq(0o700)
      expect(files.map { |file| File.stat(file).mode & 0o777 }).to eq([0o600, 0o600])
      expect(File.size(File.join(retained, 'chromedriver-startup.log'))).to eq(described_class::LOG_BYTES)
      expect(JSON.parse(File.read(File.join(retained, 'startup.json')))).to include('truncated' => true)
    end

    it('refuses an existing log without truncating its contents') do
      path = File.join(directory, 'chromedriver-startup.log')
      File.write(path, 'existing owned evidence')
      expect { diagnostics }.to raise_error(Errno::EEXIST)
      expect(File.read(path)).to eq('existing owned evidence')
    end

    it('refuses a symlinked scratch directory') do
      path = File.join(directory, 'linked')
      File.symlink(directory, path)
      expect { described_class.new(path, 'fixture') }.to raise_error(/unsafe browser diagnostic directory/)
      expect(File).not_to exist(File.join(directory, 'chromedriver-startup.log'))
    end

    it('refuses replaced log identity without retaining foreign bytes') do
      diagnostics.service.log.write('owned bytes')
      path = File.join(directory, 'chromedriver-startup.log')
      File.rename(path, "#{path}.original")
      File.write(path, 'foreign bytes', perm: 0o600)
      expect { diagnostics.retain(original_error) }.to output(/retention failed: RuntimeError/).to_stderr
      expect(File).not_to exist(ENV.fetch('BROWSER_STARTUP_ARTIFACT_DIR'))
    end

    it('retains the original exception when the diagnostic destination is unsafe') do
      File.symlink(directory, ENV.fetch('BROWSER_STARTUP_ARTIFACT_DIR'))
      fixture = prepared_fixture(RequestSecurity)
      expect { fixture.__send__(:start_browser) }.to raise_error(original_error) { |caught| expect(caught).to equal(original_error) }
      expect(Dir.children(directory)).not_to include('startup.json')
    end

    it('prints only bounded native errors without protocol or credential-shaped lines') do
      lines = ["[123:ERROR:startup.cc:1] native refusal\n", "[123:ERROR:startup.cc:1] token=synthetic-marker\n",
               "[123:ERROR:startup.cc:1] https://fixture.invalid\n", "[DEBUG] protocol ERROR: synthetic-payload\n"]
      diagnostics.service.log.write(lines.join)
      observation = StringIO.new
      allow(diagnostics).to receive(:warn) { |line| observation.puts(line) }
      diagnostics.retain(original_error)
      expect(observation.string).to include('Browser native startup: [123:ERROR:startup.cc:1] native refusal')
      expect(observation.string).not_to include('synthetic-marker', 'https://fixture.invalid', 'synthetic-payload')
      log = File.join(ENV.fetch('BROWSER_STARTUP_ARTIFACT_DIR'), '*', 'chromedriver-startup.log')
      expect(File.read(Dir.glob(log).fetch(0))).to eq(lines.join)
    end
  end
end
