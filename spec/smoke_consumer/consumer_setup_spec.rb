# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require_relative '../../lib/smoke_consumer'

RSpec.describe SmokeConsumer::Consumer do
  # Yield an owned consumer with an executable native setup fixture.
  def with_native_setup(script)
    Dir.mktmpdir('consumer-setup-observation', File.realpath(Dir.tmpdir)) do |base|
      owner = SmokeConsumer::Ownership.create(base, timeout: 30)
      path, project = owner.register_consumer('diagnostic_consumer')
      FileUtils.mkdir_p(File.join(path, 'bin'), mode: 0o700)
      File.write(File.join(path, 'bin/setup'), "#!#{RbConfig.ruby}\n$stdout.sync = true\n#{script}\n", mode: 'w', perm: 0o700)
      command = SmokeConsumer::Command.new(timeout: 20, ownership: owner)
      consumer = described_class.new(path: path, project: project, ownership: owner, command: command,
                                     environment: SmokeConsumer.environment, repository: 'example/template')
      allow(consumer.instance_variable_get(:@database)).to receive(:setup_environment).and_return({})
      yield consumer, owner, path
    end
  end

  # Produce a real failing child that writes synthetic private output.
  def nested_setup_failure
    <<~RUBY
      require #{File.expand_path('../../lib/smoke_consumer', __dir__).inspect}
      puts '== Installing locked dependencies =='
      puts 'synthetic-private-password-do-not-retain'
      begin
        SmokeConsumer::Command.new(timeout: 5).call(RbConfig.ruby, '-e', 'exit 7')
      rescue SmokeConsumer::Error
        warn 'setup: bundle failed (exit 7)'
        exit 1
      end
    RUBY
  end

  # Copy committed setup inputs into this isolated consumer.
  def real_setup_inputs(path)
    FileUtils.cp('bin/setup', File.join(path, 'bin/setup'))
    FileUtils.cp_r('lib', path)
    FileUtils.cp(['package.json', '.ruby-version', 'Gemfile.lock'], path)
    manifest = JSON.parse(File.read('package.json'))
    lock = JSON.parse(File.read('package-lock.json'))
    File.write(File.join(path, 'package-lock.json'), JSON.generate(lock.merge('lockfileVersion' => 1)))
    SmokeConsumer::Toolchain.metadata(manifest, lock, File.read('.ruby-version'), File.read('Gemfile.lock'))
  end

  # Qualify native tools and initialize the owned consumer repository.
  def prepare_real_setup(consumer, owner, path)
    metadata = real_setup_inputs(path)
    home = File.join(owner.root, 'tools')
    Dir.mkdir(home, 0o700)
    environment = SmokeConsumer::Toolchain.new(SmokeConsumer::Command.new(timeout: 180), metadata, home).environment
    consumer.instance_variable_get(:@target).environment.merge!(environment)
    SmokeConsumer::Command.new(timeout: 10).call('git', 'init', '--quiet', path)
  end

  it 'retains a sanitized native setup failure before removing the consumer tree' do
    with_native_setup(nested_setup_failure) do |consumer, owner, path|
      expect { consumer.send(:setup_twice) }.to raise_error(SmokeConsumer::Error, 'setup failed (exit 1)')
      receipt_path = File.join(owner.root, 'setup-failure-diagnostic-consumer-1.json')
      receipt = JSON.parse(File.read(receipt_path))
      expect(receipt).to include('attempt' => 1, 'exitstatus' => 1, 'termsig' => nil, 'emitted_phase' => 'locked_dependencies',
                                 'setup_error' => { 'executable' => 'bundle', 'reported_status' => 7 },
                                 'output_bytes' => be_positive, 'output_sha256' => match(/\A[a-f0-9]{64}\z/))
      expect([File.stat(owner.root).mode & 0o777, File.stat(receipt_path).mode & 0o777]).to eq([0o700, 0o600])
      FileUtils.remove_entry_secure(path)
      expect(File.file?(receipt_path)).to be(true)
    end
  end

  it 'excludes private native output and stops before the second setup on failure' do
    with_native_setup(nested_setup_failure) do |consumer, owner, path|
      expect { consumer.send(:setup_twice) }.to raise_error(SmokeConsumer::Error, 'setup failed (exit 1)')
      receipt = File.read(File.join(owner.root, 'setup-failure-diagnostic-consumer-1.json'))
      expect(receipt).not_to include('synthetic-private-password-do-not-retain', path, owner.token)
      expect(File.exist?(File.join(owner.root, 'setup-failure-diagnostic-consumer-2.json'))).to be(false)
    end
  end

  it 'records the actual committed setup prerequisite refusal through the consumer boundary' do
    with_native_setup('exit 0') do |consumer, owner, path|
      prepare_real_setup(consumer, owner, path)
      expect { consumer.send(:setup_twice) }.to raise_error(SmokeConsumer::Error, 'setup failed (exit 1)')
      receipt = JSON.parse(File.read(File.join(owner.root, 'setup-failure-diagnostic-consumer-1.json')))
      expect(receipt).to include('exitstatus' => 1, 'emitted_phase' => 'locked_dependencies', 'setup_error' => nil)
    end
  end

  it 'keeps unrecognized native output out of its failure receipt' do
    script = <<~'RUBY'
      STDOUT.binmode
      STDOUT.write("\xffsetup: secret-command failed (exit 9)\n")
      puts 'prefix setup: bundle failed (exit 9)'
      puts "\e[31m== Preparing databases ==\e[0m"
      puts '== Preparing databases == synthetic-private-password'
      exit 3
    RUBY
    with_native_setup(script) do |consumer, owner, _path|
      expect { consumer.send(:setup_twice) }.to raise_error(SmokeConsumer::Error, 'setup failed (exit 3)')
      receipt = JSON.parse(File.read(File.join(owner.root, 'setup-failure-diagnostic-consumer-1.json')))
      expect(receipt).to include('exitstatus' => 3, 'emitted_phase' => nil, 'setup_error' => nil)
      expect(JSON.generate(receipt)).not_to include('secret-command', 'setup:', 'argv', 'environment')
    end
  end

  it 'retains an actual setup signal instead of inventing an exit code' do
    with_native_setup("puts '== Preparing databases =='; Process.kill('TERM', Process.pid); sleep 10") do |consumer, owner, _path|
      expect { consumer.send(:setup_twice) }.to raise_error(SmokeConsumer::Error, 'setup failed (exit 15)')
      receipt = JSON.parse(File.read(File.join(owner.root, 'setup-failure-diagnostic-consumer-1.json')))
      expect(receipt).to include('exitstatus' => nil, 'termsig' => 15, 'emitted_phase' => 'preparing_databases', 'setup_error' => nil)
    end
  end

  it 'runs setup twice on actual success without publishing a failure receipt' do
    with_native_setup("File.open('runs', 'a') { |file| file.puts('run') }") do |consumer, owner, path|
      consumer.send(:setup_twice)
      expect(File.readlines(File.join(path, 'runs'), chomp: true)).to eq(%w[run run])
      expect(Dir.children(owner.root).grep(/\Asetup-failure-/)).to be_empty
    end
  end

  it 'records the second actual setup failure without replacing the successful first invocation' do
    script = <<~RUBY
      attempt = File.exist?('first') ? 2 : 1
      File.write('first', attempt)
      puts '== Installing configured hooks (not a provider-gate verdict) =='
      exit(attempt == 2 ? 4 : 0)
    RUBY
    with_native_setup(script) do |consumer, owner, path|
      expect { consumer.send(:setup_twice) }.to raise_error(SmokeConsumer::Error, 'setup failed (exit 4)')
      expect(File.read(File.join(path, 'first'))).to eq('2')
      expect(File.exist?(File.join(owner.root, 'setup-failure-diagnostic-consumer-1.json'))).to be(false)
      receipt = JSON.parse(File.read(File.join(owner.root, 'setup-failure-diagnostic-consumer-2.json')))
      expect(receipt).to include('attempt' => 2, 'exitstatus' => 4, 'emitted_phase' => 'configured_hooks')
    end
  end

  it 'preserves a foreign receipt and the original setup refusal when exclusive publication fails' do
    with_native_setup('exit 3') do |consumer, owner, _path|
      foreign = File.join(owner.root, 'foreign.json')
      File.write(foreign, 'preserved sentinel')
      File.symlink(foreign, File.join(owner.root, 'setup-failure-diagnostic-consumer-1.json'))
      expect { consumer.send(:setup_twice) }.to raise_error(SmokeConsumer::Error, 'setup failed (exit 3)') do |error|
        expect(error.cause).to be_a(Errno::EEXIST)
      end
      expect(File.read(foreign)).to eq('preserved sentinel')
    end
  end
end
