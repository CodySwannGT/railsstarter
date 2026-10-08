# frozen_string_literal: true

require_relative '../../lib/request_policy'
require_relative '../../lib/middleware/trusted_client_ip'
require_relative '../../lib/request_rate_limit_store'
require_relative '../fixtures/requests/request_rate_limit_harness'
require 'active_record'

RSpec.describe RequestPolicy do
  def policy(environment = {}, profile = 'test')
    described_class.new(environment, environment: profile)
  end

  it 'uses the documented configurable coordinator default and direct local sockets' do
    expect([policy.limit, policy.period, policy.ingress, policy.enabled?]).to eq([120, 60, 'direct', true])
    expect([policy('REQUEST_RATE_LIMIT' => '7').limit, policy('REQUEST_RATE_PERIOD' => '9').period]).to eq([7, 9])
  end

  it 'rejects nonpositive, fractional, padded and nonnumeric settings' do
    %w[0 -1 1.5 01 1s].each do |value|
      expect { policy('REQUEST_RATE_LIMIT' => value) }.to raise_error(ArgumentError, /REQUEST_RATE_LIMIT/)
      expect { policy('REQUEST_RATE_PERIOD' => value) }.to raise_error(ArgumentError, /REQUEST_RATE_PERIOD/)
    end
  end

  it 'requires an explicit deployed ingress even when rate limits are disabled' do
    %w[staging production].each do |environment|
      expect { policy({}, environment) }.to raise_error(ArgumentError, /REQUEST_INGRESS_PROFILE/)
      expect { policy({ 'REQUEST_RATE_LIMIT_ENABLED' => 'false' }, environment) }.to raise_error(ArgumentError, /REQUEST_INGRESS_PROFILE/)
    end
  end

  it 'requires exact supported switches, profiles and peer ranges' do
    expect { policy('REQUEST_RATE_LIMIT_ENABLED' => 'maybe') }.to raise_error(ArgumentError)
    expect { policy('REQUEST_INGRESS_PROFILE' => 'auto') }.to raise_error(ArgumentError)
    expect { policy('REQUEST_INGRESS_PROFILE' => 'thruster') }.to raise_error(ArgumentError, /THRUSTER_TRUSTED_PEERS/)
    expect { policy('REQUEST_INGRESS_PROFILE' => 'alb', 'ALB_TRUSTED_PEERS' => '0.0.0.0/0') }.to raise_error(ArgumentError, /ALB_TRUSTED_PEERS/)
    expect { policy('REQUEST_INGRESS_PROFILE' => 'alb', 'ALB_TRUSTED_PEERS' => 'host.invalid') }.to raise_error(ArgumentError)
  end

  context 'with canonical client identity' do
    def middleware(environment = {})
      Middleware::TrustedClientIp.new(->(env) { [200, {}, [env.fetch('request_policy.client_ip')]] }, policy(environment))
    end

    def client(environment, settings = {})
      middleware(settings).call({ 'PATH_INFO' => '/', 'REMOTE_ADDR' => '127.0.0.1' }.merge(environment))
    end

    it 'uses only the socket peer in direct mode despite every supplied identity header' do
      response = client('REMOTE_ADDR' => '10.1.2.3', 'HTTP_X_FORWARDED_FOR' => 'attacker', 'HTTP_FORWARDED' => 'for=1.2.3.4',
                        'HTTP_X_REAL_IP' => '1.2.3.4', 'HTTP_CLIENT_IP' => '1.2.3.4')
      expect(response.values_at(0, 2)).to eq([200, ['10.1.2.3']])
      expect(client('REMOTE_ADDR' => '::ffff:192.0.2.1')[2]).to eq(['192.0.2.1'])
    end

    it 'validates the actual Thruster socket and ignores attacker prefixes' do
      settings = { 'REQUEST_INGRESS_PROFILE' => 'thruster', 'THRUSTER_TRUSTED_PEERS' => '127.0.0.1/32' }
      expect(client({ 'HTTP_X_FORWARDED_FOR' => 'bad prefix, 10.2.3.4' }, settings)[2]).to eq(['10.2.3.4'])
      expect(client({ 'REMOTE_ADDR' => '127.0.0.2', 'HTTP_X_FORWARDED_FOR' => '10.2.3.4' }, settings)[0]).to eq(403)
      expect(client({}, settings)[0]).to eq(400)
    end

    it 'uses the ALB append suffix without discarding private client addresses' do
      settings = { 'REQUEST_INGRESS_PROFILE' => 'alb', 'ALB_TRUSTED_PEERS' => '127.0.0.1/32' }
      expect(client({ 'HTTP_X_FORWARDED_FOR' => 'spoof, 10.2.3.4:49152' }, settings)[2]).to eq(['10.2.3.4'])
      expect(client({ 'HTTP_X_FORWARDED_FOR' => 'spoof, [2001:db8::1]:443' }, settings)[2]).to eq(['2001:db8::1'])
      expect(client({ 'HTTP_X_FORWARDED_FOR' => 'garbage' }, settings)[0]).to eq(400)
    end

    it 'checks both ALB and Thruster peers and selects the penultimate appended client' do
      settings = { 'REQUEST_INGRESS_PROFILE' => 'alb_thruster', 'THRUSTER_TRUSTED_PEERS' => '127.0.0.1/32', 'ALB_TRUSTED_PEERS' => '10.9.0.0/24' }
      expect(client({ 'HTTP_X_FORWARDED_FOR' => 'spoof, 10.2.3.4, 10.9.0.2' }, settings)[2]).to eq(['10.2.3.4'])
      expect(client({ 'HTTP_X_FORWARDED_FOR' => 'spoof, 10.2.3.4, 10.8.0.2' }, settings)[0]).to eq(403)
      expect(client({ 'HTTP_X_FORWARDED_FOR' => '10.9.0.2' }, settings)[0]).to eq(400)
    end

    it 'refuses invalid addresses and ports but bypasses only the exact health path' do
      %w[hostname 1.2.3.4/24 1.2.3.4:0 [::1]:65536 fe80::1%lo0].each do |address|
        expect(client('REMOTE_ADDR' => address)[0]).to eq(400)
      end
      endpoint = Middleware::TrustedClientIp.new(->(_) { [204, {}, []] }, policy)
      expect(endpoint.call('PATH_INFO' => '/up', 'REMOTE_ADDR' => 'bad')[0]).to eq(204)
      expect(endpoint.call('PATH_INFO' => '/up/', 'REMOTE_ADDR' => 'bad')[0]).to eq(400)
    end
  end

  it 'treats optional blank peer inputs as absent and keeps selected proxy profiles mandatory' do
    expect(policy('ALB_TRUSTED_PEERS' => '', 'THRUSTER_TRUSTED_PEERS' => '', 'REQUEST_INGRESS_PROFILE' => '').ingress).to eq('direct')
    expect { policy('REQUEST_INGRESS_PROFILE' => 'alb', 'ALB_TRUSTED_PEERS' => '') }.to raise_error(ArgumentError, /ALB_TRUSTED_PEERS/)
  end

  context 'with the strict counter adapter contract' do
    let(:counter_interface) do
      Class.new do
        def self.increment_key(_key, expires_at:) = expires_at
      end
    end
    let(:counter) { class_double(counter_interface, increment_key: nil) }
    let(:store) { RequestRateLimitStore.new(namespace: 'test') }

    before { stub_const('RequestRateLimitCounter', counter) }

    it 'rejects nil and nonpositive counts without providing a write-one fallback' do
      [nil, 0, -1, '1'].each do |result|
        allow(counter).to receive(:increment_key).and_return(result)
        expect { store.increment('owned-key', 1, expires_in: 60) }.to raise_error(RequestRateLimitStore::Unavailable, /Invalid security count/)
      end
      expect(store).not_to respond_to(:write, :clear, :reset_count)
    end

    it 'refuses unsupported increments and expiry inputs before any SQL call' do
      counter
      expect { store.increment('owned-key', 2, expires_in: 60) }.to raise_error(RequestRateLimitStore::Unavailable)
      expect { store.increment('owned-key', 1.0, expires_in: 60) }.to raise_error(RequestRateLimitStore::Unavailable)
      expect { store.increment('owned-key', 1, expires_in: nil) }.to raise_error(RequestRateLimitStore::Unavailable)
      expect(counter).not_to have_received(:increment_key)
    end

    it 'translates an ambiguous SQL failure once without retrying it' do
      allow(counter).to receive(:increment_key).and_raise(ActiveRecord::StatementInvalid, 'synthetic ambiguous commit')
      expect { store.increment('owned-key', 1, expires_in: 60) }.to raise_error(RequestRateLimitStore::Unavailable, 'Security counter unavailable')
      expect(counter).to have_received(:increment_key).once
    end
  end

  def term_refusal_acknowledged?(ready, token, process)
    return false unless File.file?(ready) && File.size(ready).positive?

    JSON.parse(File.read(ready)) == { 'token' => token, 'pid' => process.pid }
  rescue JSON::ParserError
    false
  end

  def verify_term_refusal_identity(ready, process)
    identity = File.lstat(ready).then { |file| [file.file?, file.uid, file.mode & 0o777, file.nlink] }
    raise 'TERM-refusal readiness file ownership changed' unless identity == [true, Process.uid, 0o600, 1]
    raise 'TERM-refusal native child identity changed' unless RequestSecurityObservation.identity(process.pid.to_s) == process.identity
  end

  def start_term_refusal(command, directory)
    token = SecureRandom.hex(16)
    ready = File.join(directory, "ready-#{token}.json")
    payload = 'sleep 0.3; trap("TERM", "IGNORE"); File.write(ARGV.fetch(0), JSON.generate(token: ARGV.fetch(1), pid: Process.pid), mode: "wx", perm: 0o600); sleep 20'
    item = command.start([RbConfig.ruby, '-rjson', '-e', payload, ready, token])
    acknowledged = RequestSecurityDeadline.wait(2) { term_refusal_acknowledged?(ready, token, item.fetch(:process)) }
    raise 'Owned TERM-refusal child did not acknowledge readiness' unless acknowledged

    verify_term_refusal_identity(ready, item.fetch(:process))
    item
  rescue StandardError
    item&.fetch(:process)&.terminate(timeout: 2)
    raise
  end

  it 'bounds an owned command that refuses TERM, records escalation and proves absence' do
    Dir.mktmpdir('quota-command-control-') do |directory|
      command = RateLimitCommand.new(directory)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      item = start_term_refusal(command, directory)
      expect { command.finish(item, timeout: 0.2) }.to raise_error(RuntimeError, /Owned command timed out/)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 5
      expect(command.receipts.last).to include(complete: false, absent: true, signals: %w[TERM KILL])
    ensure
      item&.fetch(:process)&.terminate(timeout: 2)
    end
  end

  it 'retains the exact nonzero child status after positive process absence readbacks' do
    Dir.mktmpdir('quota-exit-control-') do |directory|
      command = RateLimitCommand.new(directory)
      expect { command.run([RbConfig.ruby, '-e', 'exit 7']) }.to raise_error(RuntimeError, /Owned command failed/)
      expect(command.receipts.last).to include(exit: 7, absent: true, complete: true)
    end
  end

  it 'builds genuine exclusive deployed assets without runtime ingress or provider access' do
    Dir.mktmpdir('quota-assets-control-') do |directory|
      probe = File.expand_path('../fixtures/requests/request_security_probe.rb', __dir__)
      output = RateLimitCommand.new(directory).run([RbConfig.ruby, probe, 'assets', 'production'], { 'REQUEST_INGRESS_PROFILE' => nil })
      result = JSON.parse(output.lines.find { |line| line.start_with?('REQUEST_SECURITY_RESULT=') }.delete_prefix('REQUEST_SECURITY_RESULT='))
      expect(result).to include('manifest_created' => true, 'booted' => true)
      expect(result.fetch('guards')).to eq('network' => 0, 'database' => 0)
      expect(result.dig('aws', 'requests')).to eq([])
    end
  end

  context 'with configured database-mode receipts' do
    let(:configured_mode) { false }
    let(:owner_mode) { false }
    let(:harness) { RequestSecurity.new(throttle_environment: configured_mode ? { 'REQUEST_RATE_ROOT' => Dir.pwd } : {}) }
    let(:token) { SecureRandom.hex(16) }
    let(:owner) { { token: token, pid: nil, cwd: Dir.pwd, ports: [], aws: { requests: [], stub_responses: true } } }

    let(:mode_state) { {} }

    def write_mode_owner(mode = owner_mode)
      record = owner.merge(database_mode: mode)
      record.delete(:database_mode) if mode == :missing
      path = File.join(mode_state.fetch(:scratch), 'server-owner.json')
      File.write(path, JSON.generate(record), mode: 'w', perm: 0o600)
      mode_state.fetch(:owners) << File.read(path)
    end

    def prepare_mode_scratch
      scratch = Dir.mktmpdir('request-owner-mode-control-')
      mode_state.merge!(scratch: scratch, identity: File.stat(scratch).then { |value| [value.dev, value.ino] }, owners: [])
      { scratch: scratch, token: token, root: Dir.pwd, ports: [] }.each { |name, value| harness.instance_variable_set("@#{name}", value) }
      File.write(File.join(scratch, 'owner.json'), JSON.generate(token: token), mode: 'wx', perm: 0o600)
      write_mode_owner
    end

    def verify_mode_scratch(path, identity)
      stat = File.lstat(path)
      raise 'Mode control scratch ownership changed' unless stat.directory? && identity == [stat.dev, stat.ino]
    end

    def retain_mode_cleanup
      scratch = mode_state.fetch(:scratch)
      verify_mode_scratch(scratch, mode_state.fetch(:identity))
      mode_state[:final_owner] = File.read(File.join(scratch, 'server-owner.json'))
      harness.stop
      mode_state[:cleanup_json] = File.read(File.join(mode_state.fetch(:directory), "cleanup-#{token}.json"))
      verify_mode_serialization
      write_mode_evidence
      mode_state[:retained] = true
    end

    def verify_mode_serialization
      actual = JSON.parse(mode_state.fetch(:cleanup_json))
      expect(actual).to eq(JSON.parse(JSON.generate(harness.cleanup_record)))
      expect(actual).to include('database_mode' => harness.instance_variable_get(:@database_mode))
      expect(actual).not_to have_key('database_access')
      expect(File.exist?(mode_state.fetch(:scratch))).to be(false)
    end

    def write_mode_evidence
      record = mode_state.slice(:owners, :final_owner, :cleanup_json, :scratch, :identity, :directory, :directory_identity)
      record[:scratch_absent] = !File.exist?(record.fetch(:scratch))
      target = ENV.fetch('REQUEST_OWNER_ARTIFACT_DIR', nil)
      File.write(File.join(target, "mode-control-#{token}.json"), JSON.pretty_generate(record), mode: 'wx', perm: 0o600) if target
    end

    around do |example|
      previous = ENV.fetch('REQUEST_SECURITY_ARTIFACT_DIR', nil)
      Dir.mktmpdir('request-owner-mode-receipts-') do |directory|
        mode_state.merge!(directory: directory, directory_identity: File.stat(directory).then { |value| [value.dev, value.ino] })
        ENV['REQUEST_SECURITY_ARTIFACT_DIR'] = directory
        prepare_mode_scratch
        example.run
      ensure
        retain_mode_cleanup unless mode_state[:retained]
        verify_mode_scratch(directory, mode_state.fetch(:directory_identity))
      end
      raise 'Mode receipt artifacts remain' if File.exist?(mode_state.fetch(:directory))
    ensure
      ENV['REQUEST_SECURITY_ARTIFACT_DIR'] = previous
    end

    [false, true].each do |mode|
      context "when the validated configured mode is #{mode}" do
        let(:configured_mode) { mode }
        let(:owner_mode) { mode }

        it 'serializes the actual validated owner mode without claiming measured database access' do
          harness.send(:validate_owner!)
          retain_mode_cleanup
          expect(harness.cleanup_record).to include(database_mode: mode)
          expect(harness.cleanup_record).not_to have_key(:database_access)
        end
      end
    end

    it 'serializes unobserved mode before any owner validation' do
      retain_mode_cleanup
      expect(harness.cleanup_record).to include(database_mode: nil)
      expect(harness.cleanup_record).not_to have_key(:database_access)
    end

    context 'when the owner mode is missing' do
      let(:owner_mode) { :missing }

      it 'refuses the owner and retains unobserved mode' do
        expect { harness.send(:validate_owner!) }.to raise_error(RuntimeError, /database mode/)
        expect(harness.instance_variable_get(:@database_mode)).to be_nil
      end
    end

    it 'refuses nonboolean owner modes without converting their truthiness' do
      [nil, 'false', 'true', 0, 1, [], {}].each do |value|
        write_mode_owner(value)
        expect { harness.send(:validate_owner!) }.to raise_error(RuntimeError, /database mode/)
        expect(harness.instance_variable_get(:@database_mode)).to be_nil
      end
    end

    it 'refuses both mismatched configured modes' do
      [false, true].each do |mode|
        harness.instance_variable_set(:@throttle_environment, mode ? { 'REQUEST_RATE_ROOT' => Dir.pwd } : {})
        write_mode_owner(!mode)
        expect { harness.send(:validate_owner!) }.to raise_error(RuntimeError, /database mode/)
        expect(harness.instance_variable_get(:@database_mode)).to be_nil
      end
    end

    it 'clears prior validation when a subsequent owner mode is invalid' do
      harness.send(:validate_owner!)
      write_mode_owner(:missing)
      expect { harness.send(:validate_owner!) }.to raise_error(RuntimeError, /database mode/)
      expect(harness.instance_variable_get(:@database_mode)).to be_nil
    end
  end

  context 'with process observation' do
    let(:observer_binary) do
      RequestSecurityExecutable.paths(ENV, ['ps']).find { |path| RequestSecurityExecutable.executable?(path) } || raise('Missing ps executable')
    end

    def genuine_observation(pid)
      output, error, status = Open3.capture3(observer_binary, '-p', pid.to_s, '-o', 'pid=,ppid=,pgid=,lstart=')
      { output: output.strip, error: error, exit: status.exitstatus }
    end

    def observer_receipt(record)
      directory = ENV.fetch('REQUEST_OBSERVER_ARTIFACT_DIR', nil)
      return unless directory

      path = File.join(directory, "control-#{record.fetch(:pid)}-#{SecureRandom.hex(8)}.json")
      File.write(path, JSON.pretty_generate(record), mode: 'wx', perm: 0o600)
    end

    def with_observed_child
      pid = Process.spawn({ 'RUBYOPT' => nil }, RbConfig.ruby, '-e', 'sleep 30', pgroup: true)
      record = { pid: pid, before: genuine_observation(pid) }
      process = RequestSecurityProcess.new(pid, child: true)
      record[:captured] = process.identity
      yield process, record
    ensure
      if process
        process.terminate(timeout: 0.2)
        record[:cleanup] = { signals: process.signals, reaped: process.reaped, observation: genuine_observation(pid) }
        observer_receipt(record)
        raise 'Observer control cleanup not proved' unless process.reaped && record[:cleanup][:observation] == { output: '', error: '', exit: 1 }
      elsif record
        observer_receipt(record.merge(cleanup_unproved: true))
      end
    end

    def with_designed_observer(output: '', error: '', exit_code: 42, delay: 0)
      original_path = ENV.fetch('PATH')
      Dir.mktmpdir('request-observer-control-') do |directory|
        program = "File.open(#{File.join(directory, 'observer-pids').dump}, 'a', 0o600) { |f| f.puts Process.pid }; " \
                  "trap('TERM', 'IGNORE') if #{delay} > 0; $stdout.write(#{output.dump}); $stdout.flush; $stderr.write(#{error.dump}); $stderr.flush; sleep #{delay}; exit #{exit_code}"
        script = "#!/bin/sh\nunset RUBYOPT\nexec #{Shellwords.escape(RbConfig.ruby)} -e #{Shellwords.escape(program)}\n"
        File.write(File.join(directory, 'ps'), script, mode: 'wx', perm: 0o700)
        ENV['PATH'] = directory + File::PATH_SEPARATOR + original_path
        yield directory
      ensure
        ENV['PATH'] = original_path
        observer_process_readback(directory, output: output, error: error, exit: exit_code, delay: delay)
      end
    end

    def observer_process_readback(directory, settings)
      path = File.join(directory, 'observer-pids')
      return unless File.file?(path)

      File.readlines(path).each do |line|
        pid = Integer(line.strip)
        observation = genuine_observation(pid)
        observer_receipt(pid: pid, designed_observer: settings, cleanup: observation)
        raise 'Designed observer cleanup not proved' unless observation == { output: '', error: '', exit: 1 }
      end
    end

    it 'rejects a failed process observation instead of skipping a captured live child' do
      with_observed_child do |process, record|
        with_designed_observer(error: "designed observer failure\n") do
          expect { process.absent? }.to raise_error(RuntimeError, /observation/)
          expect { process.terminate(timeout: 0.1) }.to raise_error(RuntimeError, /observation/)
        end
        record[:after_failure] = genuine_observation(process.pid)
        expect(record[:after_failure]).to eq(record[:before])
        expect(process.signals).to eq([])
      end
    end

    it 'rejects unknown empty or diagnostic process observations' do
      with_observed_child do |process, record|
        [{ exit_code: 0 }, { exit_code: 1, error: "observer unavailable\n" }, { output: record[:captured], exit_code: 42 },
         { output: record[:captured], exit_code: 0, error: 'partial observation' }].each do |settings|
          with_designed_observer(**settings) { expect { process.absent? }.to raise_error(RuntimeError, /observation/) }
        end
        expect(genuine_observation(process.pid)).to eq(record[:before])
      end
    end

    it 'rejects incomplete, malformed, multiple and wrong-PID process observations' do
      with_observed_child do |process, record|
        ["#{process.pid} #{Process.pid}", 'malformed', record[:captured].sub(/(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)/, 'Bogus'), "#{record[:captured]}\n#{record[:captured]}",
         record[:captured].sub(process.pid.to_s, '1')].each do |output|
          with_designed_observer(output: output, exit_code: 0) { expect { process.absent? }.to raise_error(RuntimeError, /observation/) }
        end
        expect(genuine_observation(process.pid)).to eq(record[:before])
      end
    end

    it 'rejects unavailable process observation without acknowledging cleanup' do
      with_observed_child do |process, record|
        original = ENV.fetch('PATH')
        begin
          ENV['PATH'] = ''
          expect { process.terminate(timeout: 0.1) }.to raise_error(RuntimeError, /observation/)
        ensure
          ENV['PATH'] = original
        end
        expect(genuine_observation(process.pid)).to eq(record[:before])
      end
    end

    it 'requires successful complete observation at initial capture' do
      with_observed_child do |process, _record|
        with_designed_observer(error: 'capture unavailable') do
          expect { RequestSecurityProcess.new(process.pid, child: true) }.to raise_error(RuntimeError, /observation/)
        end
        expect(process.absent?).to be(false)
      end
    end

    def expect_private_observer_cleanup(failure)
      harness = RequestSecurity.new(cleanup_timeout: 0.1)
      harness.setup_scratch
      driver = instance_double(Capybara::Selenium::Driver)
      allow(driver).to receive(:quit).and_raise(failure)
      harness.instance_variable_set(:@page, instance_double(Capybara::Session, driver: driver))
      expect { harness.stop }.to raise_error(/driver_quit.*observation timed out/)
      expect(harness.cleanup_record).to include(scratch_removed: true, observer_failures: [{ stage: :driver_quit, observation: failure.observation }])
    ensure
      harness&.stop unless harness&.cleanup_record
    end

    def expect_observer_failure(failure, observer_pid, directory)
      expect(failure.observation).to include(operation: 'identity', stage: 'waiting', observer_pid: observer_pid,
                                             reaped: true, exit: nil, signal: Signal.list.fetch('KILL'), output_bytes: 14, error_bytes: 13)
      expect(failure.observation.fetch(:elapsed)).to be >= 1
      expect(failure.observation.keys).to contain_exactly(:operation, :stage, :observer_pid, :elapsed, :reaped, :exit, :signal, :output_bytes, :error_bytes)
      expect(JSON.generate(failure.observation)).not_to include('bounded-output', 'bounded-error', directory)
    end

    it 'bounds a TERM-ignoring observer itself without treating its timeout as target absence' do
      with_observed_child do |process, record|
        failure = nil
        with_designed_observer(output: 'bounded-output', error: 'bounded-error', delay: 30) do |directory|
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          expect { process.absent? }.to raise_error(RuntimeError, /observation timed out/) { |error| failure = error }
          expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 3
          observer_pid = Integer(File.read(File.join(directory, 'observer-pids')).strip)
          expect(genuine_observation(observer_pid)).to eq(output: '', error: '', exit: 1)
          expect { Process.waitpid(observer_pid, Process::WNOHANG) }.to raise_error(Errno::ECHILD)
          expect_observer_failure(failure, observer_pid, directory)
        end
        expect_private_observer_cleanup(failure)
        expect(genuine_observation(process.pid)).to eq(record[:before])
      end
    end

    it 'checks complete profile and group tables instead of acknowledging failed empty observation' do
      with_observed_child do |process, record|
        with_designed_observer(error: 'table unavailable') do
          expect { RequestSecurityObservation.groups }.to raise_error(RuntimeError, /observation/)
          expect { RequestSecurityObservation.profiles('--user-data-dir=owned-control') }.to raise_error(RuntimeError, /observation/)
        end
        expect(RequestSecurityObservation.groups).to include(Process.getpgrp.to_s)
        expect(RequestSecurityObservation.profiles('--user-data-dir=owned-control')).to eq([])
        expect(genuine_observation(process.pid)).to eq(record[:before])
      end
    end

    it 'rejects successful but incomplete profile and group tables' do
      with_observed_child do |process, record|
        ['', 'garbage'].each do |output|
          with_designed_observer(output: output, exit_code: 0) do
            expect { RequestSecurityObservation.groups }.to raise_error(RuntimeError, /observation/)
            expect { RequestSecurityObservation.profiles('--user-data-dir=owned-control') }.to raise_error(RuntimeError, /observation/)
          end
        end
        expect(genuine_observation(process.pid)).to eq(record[:before])
      end
    end
  end
end
