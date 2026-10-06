# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require_relative '../../lib/smoke_consumer'

RSpec.describe SmokeConsumer do # rubocop:disable RSpec/SpecFilePathFormat -- exact public CLI spec path admitted by parent.
  it 'runs the public command for two fresh named consumers without skipping prerequisites' do
    command = SmokeConsumer::Command.new(timeout: 1865)
    output, status = command.call(RbConfig.ruby, File.expand_path('../../bin/smoke-consumer', __dir__), timeout: 1860, allow_failure: true)
    expect(status.success?).to be(true), output
    result = JSON.parse(output.lines.find { |line| line.start_with?('{') })
    expect(result.fetch('consumers').map { |consumer| consumer.values_at('name', 'setup_runs') }).to eq([['smoke_consumer', 2], ['smoke_consumer_two', 2]])
    expect(result.fetch('consumers').map { |consumer| consumer.fetch('http') }).to all(eq('/' => 200, '/up' => 200))
    expect(result.fetch('consumers').map { |consumer| consumer.fetch('job').fetch('finished') }).to eq([true, true])
    cleanup = JSON.parse(File.read(File.join(result.fetch('evidence_root'), 'cleanup.json')))
    expect(cleanup.fetch('clean')).to be(true)
  end

  it 'rejects a single destination before any allocation' do
    expect { SmokeConsumer::Consumer.run(source: 'HEAD', names: ['smoke_consumer'], timeout: 5) }.to raise_error(SmokeConsumer::Error, /Exactly two/)
  end

  it 'drains large native output without waiting on an empty status pipe between chunks' do
    command = described_class::Command.new(timeout: 10)
    script = "$stdout.binmode; 512.times { $stdout.write('x' * 16_384) }; exit 17"
    output, status = command.capture(RbConfig.ruby, '-e', script, timeout: 5)

    expect(output).to eq('x' * (8 * 1024 * 1024))
    expect(status.exitstatus).to eq(17)
    expect(status.success?).to be(false)
  end

  it 'refuses native output beyond the existing sixteen MiB bound' do
    command = described_class::Command.new(timeout: 10)
    script = "$stdout.binmode; 1025.times { $stdout.write('x' * 16_384) }"
    expect { command.capture(RbConfig.ruby, '-e', script, timeout: 5) }
      .to raise_error(described_class::Error, 'Child output exceeded 16 MiB')
  end

  it 'captures the genuine committed archive within its original twenty-second deadline' do
    command = described_class::Command.new(timeout: 30)
    commit, = command.call('git', 'rev-parse', '--verify', 'HEAD^{commit}', timeout: 10)
    archive, status = command.capture('git', 'archive', '--format=tar', commit.strip, timeout: 20)
    setup, = command.call('git', 'show', "#{commit.strip}:bin/setup", timeout: 10)
    entries = Gem::Package::TarReader.new(StringIO.new(archive))
    archived_setup = entries.find { |entry| entry.full_name == 'bin/setup' }.read

    expect(status.success?).to be(true)
    expect(archived_setup).to eq(setup)
  end

  it 'refuses suppressed automatic full apply instead of faking CI or skipping lifecycle' do
    expect do
      SmokeConsumer::Toolchain.require_install_only('postinstall' => 'LISA_BOOTSTRAP=1 node index.js 2>/dev/null || true')
    end.to raise_error(SmokeConsumer::Error, /genuine released install-only/)
  end

  it 'retains an install-only lifecycle' do
    expect { SmokeConsumer::Toolchain.require_install_only('postinstall' => 'node scripts/lisa-postinstall.mjs') }.not_to raise_error
  end

  def locked_toolchain_metadata
    described_class::Toolchain.metadata(
      JSON.parse(File.read('package.json')), JSON.parse(File.read('package-lock.json')),
      File.read('.ruby-version'), File.read('Gemfile.lock')
    )
  end

  it 'prepares the exact locked Bundler in a private HOME before consumer setup' do
    Dir.mktmpdir('consumer-bundler', File.realpath(Dir.tmpdir)) do |home|
      command = described_class::Command.new(timeout: 180)
      metadata = locked_toolchain_metadata
      environment = described_class::Toolchain.new(command, metadata, home).environment
      output, status = command.call('bundle', '--version', env: environment, timeout: 10)

      expect(status.success?).to be(true)
      expect(output.strip).to eq("Bundler version #{metadata.fetch('bundler')}")
      expect(environment.fetch('HOME')).to eq(home)
      expect(environment.fetch('GEM_HOME')).to eq(File.join(home, 'gems'))
      expect(environment.fetch('BUNDLER_VERSION')).to eq(metadata.fetch('bundler'))
    end
  end

  it 'refuses missing locked Bundler metadata before executing an installer' do
    Dir.mktmpdir('consumer-bundler', File.realpath(Dir.tmpdir)) do |home|
      command = described_class::Command.new(timeout: 10)
      environment = { 'HOME' => home, 'PATH' => ENV.fetch('PATH') }
      expect { described_class::BundlerTool.new(command, nil, environment, home).prepare }
        .to raise_error(described_class::Error, /unsupported bundle engine contract/)
      expect(File.exist?(File.join(home, 'gems'))).to be(false)
    end
  end

  it 'refuses a genuinely unavailable Bundler installer without reporting setup success' do
    Dir.mktmpdir('consumer-bundler', File.realpath(Dir.tmpdir)) do |home|
      command = described_class::Command.new(timeout: 30)
      environment = { 'HOME' => home, 'PATH' => File.join(home, 'missing-bin') }
      expect { described_class::BundlerTool.new(command, '2.4.10', environment, home).prepare }
        .to raise_error(described_class::Error, /Bundler 2.4.10 installation failed/)
    end
  end

  it 'retains an actually qualified installed Bundler without creating a private installation' do
    Dir.mktmpdir('consumer-bundler', File.realpath(Dir.tmpdir)) do |home|
      command = described_class::Command.new(timeout: 30)
      environment = { 'HOME' => home, 'PATH' => ENV.fetch('PATH') }
      baseline, = command.call('bundle', '--version', env: environment, timeout: 10)
      expected = baseline.strip.delete_prefix('Bundler version ')
      described_class::BundlerTool.new(command, expected, environment, home).prepare
      output, status = command.call('bundle', '--version', env: environment, timeout: 10)
      expect(status.success?).to be(true)
      expect(output.strip).to eq("Bundler version #{expected}")
      expect(File.exist?(File.join(home, 'gems'))).to be(false)
    end
  end

  def write_setup_refusal_fixture(app, lock)
    FileUtils.mkdir_p(File.join(app, 'bin'))
    FileUtils.cp('bin/setup', File.join(app, 'bin/setup'))
    FileUtils.cp_r('lib', app)
    FileUtils.cp(['package.json', '.ruby-version', 'Gemfile.lock'], app)
    File.write(File.join(app, 'package-lock.json'), JSON.generate(lock.merge('lockfileVersion' => 1)))
  end

  it 'carries qualified private Bundler through the public setup prerequisite check' do
    Dir.mktmpdir('consumer-bundler-setup', File.realpath(Dir.tmpdir)) do |base|
      home = File.join(base, 'home')
      app = File.join(base, 'app')
      FileUtils.mkdir_p([home, app])
      command = described_class::Command.new(timeout: 180)
      lock = JSON.parse(File.read('package-lock.json'))
      metadata = locked_toolchain_metadata
      environment = described_class::Toolchain.new(command, metadata, home).environment
      write_setup_refusal_fixture(app, lock)
      command.call('git', 'init', '--quiet', app, timeout: 10)
      output, status = command.capture(RbConfig.ruby, File.join(app, 'bin/setup'), '--skip-server', env: environment, chdir: app, timeout: 30)

      expect(status.exitstatus).to eq(1)
      expect(output).to include('Installing locked dependencies', 'malformed or mismatched dependency carrier')
      expect(File.exist?(File.join(app, 'node_modules'))).to be(false)
    end
  end

  it 'preserves actual installed Docker plugins and daemon identity in a credential-free private config' do
    command = described_class::Command.new(timeout: 60)
    commands = [%w[docker compose version --short], %w[docker buildx version], ['docker', 'info', '--format', '{{.ID}}']]
    before = commands.map { |arguments| command.call(*arguments, timeout: 15).first }
    Dir.mktmpdir('consumer-smoke-docker-config', File.realpath(Dir.tmpdir)) do |home|
      environment = { 'HOME' => home, 'PATH' => ENV.fetch('PATH') }
      described_class::InstalledDocker.new(command, environment, home).prepare
      after = commands.map { |arguments| command.call(*arguments, env: environment, timeout: 15).first }
      directory = environment.fetch('DOCKER_CONFIG')
      config = File.join(directory, 'config.json')
      expect(after).to eq(before)
      expect(environment.fetch('HOME')).to eq(home)
      expect(JSON.parse(File.read(config)).keys).to eq(['cliPluginsExtraDirs'])
      expect([File.stat(directory).mode & 0o777, File.stat(config).mode & 0o777]).to eq([0o700, 0o600])
    end
  end

  it 'refuses a preexisting private Docker config without reusing or copying its credentials' do
    command = described_class::Command.new(timeout: 60)
    Dir.mktmpdir('consumer-smoke-existing-docker-config', File.realpath(Dir.tmpdir)) do |home|
      directory = File.join(home, 'docker-config')
      Dir.mkdir(directory, 0o700)
      sentinel = File.join(directory, 'config.json')
      File.write(sentinel, 'preserved fixture sentinel')
      environment = { 'HOME' => home, 'PATH' => ENV.fetch('PATH') }
      expect { described_class::InstalledDocker.new(command, environment, home).prepare }.to raise_error(Errno::EEXIST)
      expect(File.read(sentinel)).to eq('preserved fixture sentinel')
      expect(environment).not_to have_key('DOCKER_CONFIG')
    end
  end

  context 'with install-only lifecycle provenance' do
    let(:released_script) { '[ -n "$CI" ] || LISA_BOOTSTRAP=1 node node_modules/@codyswann/lisa/all/copy-overwrite/scripts/lisa-postinstall.mjs || true' }
    let(:released_metadata) do
      { 'postinstall' => released_script, 'lisa' => '4.70.1',
        'lisa_resolved' => 'https://registry.npmjs.org/@codyswann/lisa/-/lisa-4.70.1.tgz',
        'lisa_integrity' => 'sha512-PwclAzApLzJ4Yk2Qn3F5dOySvUGhk3r9AHNCyz6arfrPj18Z07Z2qY7Bss+pVDmsbHkJNWfPxEzJ7tosvVgKMQ==' }
    end

    it 'accepts the exact genuine released install-only lifecycle tuple' do
      expect { described_class::Toolchain.require_install_only(released_metadata) }.not_to raise_error
    end

    it 'accepts the verified 4.70.2 install-only release' do
      metadata = released_metadata.merge(
        'lisa' => '4.70.2', 'lisa_resolved' => 'https://registry.npmjs.org/@codyswann/lisa/-/lisa-4.70.2.tgz',
        'lisa_integrity' => 'sha512-x55lWqlnE52eG/Ha0NNYAs50pxbhe+vYf5XQSgH4CaEtym9gWvJAa5YUJPWt3MfYJSsybp7qmmclxmuaKA/Ceg=='
      )
      expect { described_class::Toolchain.require_install_only(metadata) }.not_to raise_error
    end

    it 'accepts the verified current 4.70.3 install-only release' do
      metadata = released_metadata.merge(
        'lisa' => '4.70.3', 'lisa_resolved' => 'https://registry.npmjs.org/@codyswann/lisa/-/lisa-4.70.3.tgz',
        'lisa_integrity' => 'sha512-It9PqbBhe3CNmfzoJ84kWFcNmzZjnFEUvcsF4XVGxSwrqsy6VUQxqA6AqzLv3zjwu0zb36sf5P9SwJW5GAhMqA=='
      )
      expect { described_class::Toolchain.require_install_only(metadata) }.not_to raise_error
    end

    it 'retains the real release provenance through lock metadata extraction' do
      lisa = { 'version' => released_metadata.fetch('lisa'), 'resolved' => released_metadata.fetch('lisa_resolved'),
               'integrity' => released_metadata.fetch('lisa_integrity'), 'engines' => { 'node' => '22.23.3', 'bun' => '1.3.8' } }
      metadata = described_class::Toolchain.metadata({ 'scripts' => { 'postinstall' => released_script } },
                                                     { 'packages' => { 'node_modules/@codyswann/lisa' => lisa } }, '3.4.11', "BUNDLED WITH\n   2.4.10\n")
      expect { described_class::Toolchain.require_install_only(metadata) }.not_to raise_error
    end

    it 'rejects the same install-only filename backed by the historical applying release' do
      metadata = released_metadata.merge('lisa' => '2.217.1')
      expect { described_class::Toolchain.require_install_only(metadata) }.to raise_error(described_class::Error)
    end

    it 'rejects a changed release integrity' do
      metadata = released_metadata.merge('lisa_integrity' => 'not-the-released-integrity')
      expect { described_class::Toolchain.require_install_only(metadata) }.to raise_error(described_class::Error)
    end

    it 'rejects a different release origin' do
      metadata = released_metadata.merge('lisa_resolved' => 'https://example.invalid/lisa.tgz')
      expect { described_class::Toolchain.require_install_only(metadata) }.to raise_error(described_class::Error)
    end

    it 'rejects an appended applying command' do
      metadata = released_metadata.merge('postinstall' => "#{released_script}; node index.js apply .")
      expect { described_class::Toolchain.require_install_only(metadata) }.to raise_error(described_class::Error)
    end

    it 'rejects an explicit applying lifecycle without the legacy marker' do
      expect { described_class::Toolchain.require_install_only('postinstall' => 'node index.js apply .') }.to raise_error(described_class::Error)
    end
  end

  context 'with a dependency carrier' do
    let(:dependency_command) { instance_spy(described_class::Command) }
    let(:dependency_metadata) { { 'lisa' => '4.70.1', 'node' => '22.23.3', 'bun' => '1.3.8' } }

    def with_dependency_carrier
      Dir.mktmpdir('consumer-smoke-dependencies', File.realpath(Dir.tmpdir)) do |base|
        File.write(File.join(base, 'package.json'), JSON.generate('name' => 'named-consumer'))
        File.write(File.join(base, 'package-lock.json'), JSON.generate('name' => 'named-consumer', 'lockfileVersion' => 3))
        yield base, described_class::DependencyInstall.new(dependency_command, base)
      end
    end

    def write_installed_dependency(base, version = '4.70.1')
      directory = File.join(base, 'node_modules/@codyswann/lisa')
      FileUtils.mkdir_p(directory)
      File.write(File.join(directory, 'package.json'), JSON.generate('version' => version, 'engines' => { 'node' => '22.23.3', 'bun' => '1.3.8' }))
    end

    it 'imports the real npm carrier first and freezes the next setup run' do
      with_dependency_carrier do |base, install|
        environment = { 'HOME' => base }
        allow(dependency_command).to receive(:call).with('bun', 'install', env: environment, chdir: base) do
          File.write(File.join(base, 'bun.lock'), 'unit boundary fixture; Bun validates its format on the next call')
          write_installed_dependency(base)
        end
        allow(dependency_command).to receive(:call).with('bun', 'install', '--frozen-lockfile', env: environment, chdir: base)
        2.times { install.call(environment, dependency_metadata) }
        expect(dependency_command).to have_received(:call).with('bun', 'install', env: environment, chdir: base).ordered
        expect(dependency_command).to have_received(:call).with('bun', 'install', '--frozen-lockfile', env: environment, chdir: base).ordered
      end
    end

    it 'uses frozen installation for a preexisting binary Bun lock' do
      with_dependency_carrier do |base, install|
        File.write(File.join(base, 'bun.lockb'), 'unit boundary fixture')
        write_installed_dependency(base)
        install.call({}, dependency_metadata)
        expect(dependency_command).to have_received(:call).with('bun', 'install', '--frozen-lockfile', env: {}, chdir: base)
      end
    end

    it 'refuses a missing npm carrier before invoking the installer' do
      with_dependency_carrier do |base, install|
        File.unlink(File.join(base, 'package-lock.json'))
        expect { install.call({}, dependency_metadata) }.to raise_error(described_class::Error, /dependency carrier/)
        expect(dependency_command).not_to have_received(:call)
      end
    end

    it 'refuses malformed npm metadata before invoking the installer' do
      with_dependency_carrier do |base, install|
        File.write(File.join(base, 'package-lock.json'), '{broken')
        expect { install.call({}, dependency_metadata) }.to raise_error(described_class::Error, /dependency carrier/)
        expect(dependency_command).not_to have_received(:call)
      end
    end

    it 'refuses an npm carrier from a different renamed package' do
      with_dependency_carrier do |base, install|
        File.write(File.join(base, 'package-lock.json'), JSON.generate('name' => 'other-consumer', 'lockfileVersion' => 3))
        expect { install.call({}, dependency_metadata) }.to raise_error(described_class::Error, /dependency carrier/)
        expect(dependency_command).not_to have_received(:call)
      end
    end

    it 'refuses a symlinked Bun lock before invoking the installer' do
      with_dependency_carrier do |base, install|
        File.symlink(File.join(base, 'package-lock.json'), File.join(base, 'bun.lock'))
        expect { install.call({}, dependency_metadata) }.to raise_error(described_class::Error, /owned regular file/)
        expect(dependency_command).not_to have_received(:call)
      end
    end

    it 'does not fall back or proceed after a failed first import' do
      with_dependency_carrier do |_, install|
        allow(dependency_command).to receive(:call).and_raise(described_class::Error, 'bun failed')
        expect { install.call({}, dependency_metadata) }.to raise_error(described_class::Error, 'bun failed')
        expect(dependency_command).to have_received(:call).once
      end
    end

    it 'refuses an import that creates no real Bun lock' do
      with_dependency_carrier do |base, install|
        allow(dependency_command).to receive(:call) { write_installed_dependency(base) }
        expect { install.call({}, dependency_metadata) }.to raise_error(described_class::Error, /Bun lock/)
      end
    end

    it 'refuses an unsupported npm carrier before installation' do
      with_dependency_carrier do |base, install|
        File.write(File.join(base, 'package-lock.json'), JSON.generate('name' => 'named-consumer', 'lockfileVersion' => 1))
        expect { install.call({}, dependency_metadata) }.to raise_error(described_class::Error, /dependency carrier/)
        expect(dependency_command).not_to have_received(:call)
      end
    end

    it 'refuses a changed preexisting frozen Bun lock' do
      with_dependency_carrier do |base, install|
        file = File.join(base, 'bun.lock')
        File.write(file, 'unit boundary fixture')
        allow(dependency_command).to receive(:call) do
          File.write(file, 'changed by installer')
          write_installed_dependency(base)
        end
        expect { install.call({}, dependency_metadata) }.to raise_error(described_class::Error, /carrier changed/)
      end
    end

    it 'refuses a changed npm carrier after installation' do
      with_dependency_carrier do |base, install|
        allow(dependency_command).to receive(:call) do
          File.write(File.join(base, 'bun.lock'), 'unit boundary fixture')
          File.write(File.join(base, 'package-lock.json'), 'changed')
          write_installed_dependency(base)
        end
        expect { install.call({}, dependency_metadata) }.to raise_error(described_class::Error, /carrier changed/)
      end
    end

    it 'refuses an installed Lisa with different engine requirements' do
      with_dependency_carrier do |base, install|
        allow(dependency_command).to receive(:call) do
          File.write(File.join(base, 'bun.lock'), 'unit boundary fixture')
          write_installed_dependency(base)
          File.write(File.join(base, 'node_modules/@codyswann/lisa/package.json'), JSON.generate('version' => '4.70.1', 'engines' => { 'node' => '22.21.1', 'bun' => '1.3.8' }))
        end
        expect { install.call({}, dependency_metadata) }.to raise_error(described_class::Error, /installed Lisa/)
      end
    end

    it 'refuses a different installed Lisa version' do
      with_dependency_carrier do |base, install|
        allow(dependency_command).to receive(:call) do
          File.write(File.join(base, 'bun.lock'), 'unit boundary fixture')
          write_installed_dependency(base, '2.217.1')
        end
        expect { install.call({}, dependency_metadata) }.to raise_error(described_class::Error, /installed Lisa/)
      end
    end
  end

  it 'rejects traversal names before a source/provider/resource call' do
    expect { SmokeConsumer::Consumer.run(source: 'HEAD', names: ['../foreign', 'smoke_two'], timeout: 5) }.to raise_error(SmokeConsumer::Error, /safe consumer names/)
  end

  it 'bounds an actually sleeping child and reaps it' do
    command = SmokeConsumer::Command.new(timeout: 0.2)
    expect { command.call(RbConfig.ruby, '-e', 'sleep 20', timeout: 0.1) }.to raise_error(SmokeConsumer::Error, /deadline exceeded/)
  end

  it 'refuses an unsigned foreign process identity without signalling it' do
    Dir.mktmpdir('consumer-smoke-manifest', File.realpath(Dir.tmpdir)) do |base|
      ownership = SmokeConsumer::Ownership.create(base, timeout: 5)
      file = File.join(ownership.root, 'manifest.json')
      data = JSON.parse(File.read(file))
      data['processes'] << SmokeConsumer::Ownership.identity_for(Process.pid).merge('mac' => 'forged')
      File.write(file, JSON.generate(data))
      expect { ownership.read }.to raise_error(SmokeConsumer::Error, 'Process ownership changed')
      expect(Process.kill(0, Process.pid)).to eq(1)
    end
  end

  it 'refuses a symlinked ownership base before writing a manifest' do
    Dir.mktmpdir('consumer-smoke-ancestor', File.realpath(Dir.tmpdir)) do |base|
      link = File.join(base, 'link')
      File.symlink(base, link)
      expect { SmokeConsumer::Ownership.create(link, timeout: 5) }.to raise_error(SmokeConsumer::Error, /Symlinked/)
    end
  end

  it 'exports no private configuration and retains only the supported worker alias' do
    archive = StringIO.new
    Gem::Package::TarWriter.new(archive) do |tar|
      tar.add_file('.lisa/work-item-context.md', 0o600) { |io| io.write('private sentinel') }
      tar.add_file('config/master.key', 0o600) { |io| io.write('private sentinel') }
      tar.add_file('Dockerfile.local', 0o600) { |io| io.write('owned fixture') }
      tar.add_symlink('worker.Dockerfile.local', 'Dockerfile.local', 0o777)
    end
    Dir.mktmpdir('consumer-smoke-export', File.realpath(Dir.tmpdir)) do |base|
      destination = File.join(base, 'named_consumer')
      SmokeConsumer::Rename.export(archive.string, destination)
      expect(File.exist?(File.join(destination, '.lisa'))).to be(false)
      expect(File.exist?(File.join(destination, 'config/master.key'))).to be(false)
      expect(File.readlink(File.join(destination, 'worker.Dockerfile.local'))).to eq('Dockerfile.local')
    end
  end

  it 'refuses an archive traversal without touching a neighbouring sentinel' do
    archive = StringIO.new
    Gem::Package::TarWriter.new(archive) { |tar| tar.add_file('../sentinel', 0o600) { |io| io.write('overwrite') } }
    Dir.mktmpdir('consumer-smoke-traversal', File.realpath(Dir.tmpdir)) do |base|
      sentinel = File.join(base, 'sentinel')
      File.write(sentinel, 'preserved')
      expect { SmokeConsumer::Rename.export(archive.string, File.join(base, 'named_consumer')) }.to raise_error(SmokeConsumer::Error, /Unsafe archive path/)
      expect(File.read(sentinel)).to eq('preserved')
    end
  end

  it 'exports a genuine committed Git archive without extracting its global metadata' do
    command = described_class::Command.new(timeout: 30)
    source, = command.capture('git', 'rev-parse', 'HEAD', timeout: 10)
    archive, status = command.capture('git', 'archive', '--format=tar', 'HEAD', timeout: 20)
    setup, = command.capture('git', 'show', 'HEAD:bin/setup', timeout: 10)
    expect(status.success?).to be(true)

    Dir.mktmpdir('consumer-smoke-git-export', File.realpath(Dir.tmpdir)) do |base|
      destination = File.join(base, 'named_consumer')
      described_class::Rename.export(archive, destination, source: source.strip)
      expect(File.binread(File.join(destination, 'bin/setup'))).to eq(setup)
      expect(File.exist?(File.join(destination, 'pax_global_header'))).to be(false)
      expect(File.exist?(File.join(destination, '.lisa'))).to be(false)
      expect(File.readlink(File.join(destination, 'worker.Dockerfile.local'))).to eq('Dockerfile.local')
    end
  end

  describe 'Git archive metadata' do
    def metadata_archive(body, typeflag: 'g')
      header = Gem::Package::TarHeader.new(name: 'pax_global_header', prefix: '', mode: 0o600, size: body.bytesize, typeflag: typeflag)
      header.to_s + body.ljust(512, "\0") + ("\0" * 1024)
    end

    it 'refuses malformed explicit source identities before creating a destination' do
      Dir.mktmpdir('consumer-smoke-invalid-source', File.realpath(Dir.tmpdir)) do |base|
        destination = File.join(base, 'named_consumer')
        ['', false, 123, 'a' * 39, 'A' * 40].each do |source|
          expect { SmokeConsumer::Rename.export('', destination, source: source) }
            .to raise_error(SmokeConsumer::Error, 'Invalid archive source identity')
          expect(File.exist?(destination)).to be(false)
        end
      end
    end

    it 'refuses a genuine archive whose comment belongs to a different accepted commit' do
      command = SmokeConsumer::Command.new(timeout: 30)
      archive, = command.capture('git', 'archive', '--format=tar', 'HEAD', timeout: 20)
      different, = command.capture('git', 'rev-parse', 'HEAD^', timeout: 10)
      Dir.mktmpdir('consumer-smoke-mismatched-source', File.realpath(Dir.tmpdir)) do |base|
        destination = File.join(base, 'named_consumer')
        expect { SmokeConsumer::Rename.export(archive, destination, source: different.strip) }
          .to raise_error(SmokeConsumer::Error, 'Git archive source metadata differs')
        expect(Dir.children(destination)).to be_empty
      end
    end

    it 'refuses metadata with an incorrect declared record length' do
      archive = metadata_archive("51 comment=#{'a' * 40}\n")
      Dir.mktmpdir('consumer-smoke-malformed-metadata', File.realpath(Dir.tmpdir)) do |base|
        expect { SmokeConsumer::Rename.export(archive, File.join(base, 'named_consumer')) }
          .to raise_error(SmokeConsumer::Error, 'Git archive source metadata differs')
      end
    end

    it 'refuses global path overrides without creating their target' do
      archive = metadata_archive("52 path=#{'x' * 43}\n")
      Dir.mktmpdir('consumer-smoke-pax-path', File.realpath(Dir.tmpdir)) do |base|
        destination = File.join(base, 'named_consumer')
        expect { SmokeConsumer::Rename.export(archive, destination) }
          .to raise_error(SmokeConsumer::Error, 'Git archive source metadata differs')
        expect(Dir.children(destination)).to be_empty
      end
    end

    it 'refuses extended per-file metadata rather than applying its overrides' do
      archive = metadata_archive("52 comment=#{'a' * 40}\n", typeflag: 'x')
      Dir.mktmpdir('consumer-smoke-extended-metadata', File.realpath(Dir.tmpdir)) do |base|
        expect { SmokeConsumer::Rename.export(archive, File.join(base, 'named_consumer')) }
          .to raise_error(SmokeConsumer::Error, 'Unsupported archive entry')
      end
    end

    it 'refuses repeated global metadata instead of replacing its original source identity' do
      archive = metadata_archive("52 comment=#{'a' * 40}\n")
      repeated = archive.byteslice(0, 1024) + archive
      Dir.mktmpdir('consumer-smoke-repeated-metadata', File.realpath(Dir.tmpdir)) do |base|
        expect { SmokeConsumer::Rename.export(repeated, File.join(base, 'named_consumer')) }
          .to raise_error(SmokeConsumer::Error, 'Unsupported Git archive metadata')
      end
    end

    it 'requires source metadata when exporting a genuine consumer' do
      archive = StringIO.new
      Gem::Package::TarWriter.new(archive) { |tar| tar.add_file('owned', 0o600) { |io| io.write('fixture') } }
      Dir.mktmpdir('consumer-smoke-missing-metadata', File.realpath(Dir.tmpdir)) do |base|
        expect { SmokeConsumer::Rename.export(archive.string, File.join(base, 'named_consumer'), source: 'a' * 40) }
          .to raise_error(SmokeConsumer::Error, 'Git archive source metadata missing')
      end
    end
  end

  it 'renames rendered application and wiki identities without forging a provider binding' do
    Dir.mktmpdir('consumer-smoke-rename', File.realpath(Dir.tmpdir)) do |base|
      %w[config app/views/layouts app/views/pwa wiki].each { |path| FileUtils.mkdir_p(File.join(base, path)) }
      File.write(File.join(base, 'config/application.rb'), "module App\n# Your Project\nend\n")
      File.write(File.join(base, 'app/views/layouts/application.html.erb'), '<title>Your Project</title>')
      File.write(File.join(base, 'app/views/pwa/manifest.json.erb'), '{"name":"Your Project"}')
      File.write(File.join(base, 'wiki/lisa-wiki.config.json'), '{"org":"your-org","displayName":"Your Project"}')
      File.write(File.join(base, '.lisa.config.json'), JSON.generate('github' => { 'org' => 'CodySwannGT', 'repo' => 'railsstarter' }))
      result = SmokeConsumer::Rename.apply(base, 'named_consumer', 'CodySwannGT/railsstarter')
      expect(File.read(File.join(base, 'config/application.rb'))).to include('module NamedConsumer', '# Named Consumer')
      expect(File.read(File.join(base, 'app/views/layouts/application.html.erb'))).to include('Named Consumer')
      expect(File.read(File.join(base, 'app/views/pwa/manifest.json.erb'))).to include('Named Consumer')
      expect(JSON.parse(File.read(File.join(base, 'wiki/lisa-wiki.config.json')))).to eq('org' => 'CodySwannGT', 'displayName' => 'Named Consumer')
      expect(result.values_at('provider_binding', 'provider_gate_verified')).to eq([nil, false])
    end
  end

  describe 'private consumer fixture evidence' do
    def fixture_consumer(path)
      FileUtils.mkdir_p(File.join(path, 'app/jobs'))
      fixture = 'test/runtime/consumer_smoke/fixture_job.rb'
      FileUtils.mkdir_p(File.dirname(File.join(path, fixture)))
      FileUtils.copy_file(File.expand_path("../../#{fixture}", __dir__), File.join(path, fixture))
      SmokeConsumer::Consumer.new(path: path, project: 'fixture-project', ownership: nil, command: nil,
                                  environment: {}, repository: 'CodySwannGT/railsstarter')
    end

    it 'installs the genuine fixture without reusing committed public evidence' do
      Dir.mktmpdir('consumer-smoke-public-evidence', File.realpath(Dir.tmpdir)) do |path|
        consumer = fixture_consumer(path)
        FileUtils.mkdir_p(File.join(path, 'evidence'))
        public_file = File.join(path, 'evidence/source-sentinel')
        File.write(public_file, 'preserved source evidence')
        consumer.send(:install_fixture)
        expect(File.read(public_file)).to eq('preserved source evidence')
        private_evidence = File.join(path, 'tmp/consumer-smoke-evidence')
        expect(File.directory?(private_evidence)).to be(true)
        expect(File.stat(private_evidence).mode & 0o777).to eq(0o700)
        expect(File.binread(File.join(path, 'app/jobs/consumer_smoke_fixture_job.rb')))
          .to eq(File.binread(File.join(path, 'test/runtime/consumer_smoke/fixture_job.rb')))
      end
    end

    it 'refuses a preexisting private evidence path without touching its sentinel' do
      Dir.mktmpdir('consumer-smoke-existing-evidence', File.realpath(Dir.tmpdir)) do |path|
        consumer = fixture_consumer(path)
        private_evidence = File.join(path, 'tmp/consumer-smoke-evidence')
        FileUtils.mkdir_p(private_evidence)
        sentinel = File.join(private_evidence, 'sentinel')
        File.write(sentinel, 'preserved')
        expect { consumer.send(:install_fixture) }.to raise_error(Errno::EEXIST)
        expect(File.read(sentinel)).to eq('preserved')
        expect(File.exist?(File.join(path, 'app/jobs/consumer_smoke_fixture_job.rb'))).to be(false)
      end
    end

    it 'refuses a symlinked evidence parent without writing into the foreign directory' do
      Dir.mktmpdir('consumer-smoke-symlink-evidence', File.realpath(Dir.tmpdir)) do |base|
        path = File.join(base, 'consumer')
        foreign = File.join(base, 'foreign')
        FileUtils.mkdir_p(foreign)
        consumer = fixture_consumer(path)
        File.symlink(foreign, File.join(path, 'tmp'))
        expect { consumer.send(:install_fixture) }.to raise_error(SmokeConsumer::Error, 'Foreign fixture evidence parent')
        expect(Dir.children(foreign)).to be_empty
        expect(File.exist?(File.join(path, 'app/jobs/consumer_smoke_fixture_job.rb'))).to be(false)
      end
    end
  end

  it 'observes the clock again after every unsuccessful wait and refuses expired work' do
    allow(described_class).to receive(:clock).and_return(10, 10.01, 10.2)
    deadline = described_class::Deadline.new(0.1)
    observations = 0
    expect do
      deadline.poll('expired') do
        observations += 1
        false
      end
    end.to raise_error(described_class::Error, 'expired')
    expect(observations).to eq(1)
  end

  it 'captures a real failed child status without treating its output as success' do
    output, status = described_class::Command.new(timeout: 5).capture(RbConfig.ruby, '-e', "puts 'actual child'; exit 7", timeout: 2)
    expect(output).to eq("actual child\n")
    expect(status.exitstatus).to eq(7)
    expect { described_class::CommandStatus.new('ruby', status).require_success }.to raise_error(described_class::Error, 'ruby failed (exit 7)')
  end

  it 'reports an actually missing child executable as an essential prerequisite' do
    expect do
      described_class::Command.new(timeout: 5).call('/missing-consumer-smoke-executable', timeout: 2)
    end.to raise_error(described_class::Error, /executable missing-consumer-smoke-executable unavailable/)
  end

  it 'checks the signed ownership again when a resource is removed later' do
    labels = { described_class::LABEL => 'owned-token', 'com.docker.compose.project' => 'owned-project' }
    object = { 'Name' => 'owned-project_mysql_data', 'Labels' => labels }
    owner = instance_double(described_class::Ownership, token: 'owned-token')
    allow(owner).to receive(:read).and_return({ 'projects' => ['owned-project'], 'resources' => [] }, { 'projects' => [], 'resources' => [] })
    resource = described_class::VolumeResource.new(object, owner)
    expect { resource.verify }.not_to raise_error
    expect { resource.verify }.to raise_error(described_class::Error, 'Docker ownership mismatch')
  end

  it 'refuses a correctly labelled but unplanned Docker volume name' do
    labels = { described_class::LABEL => 'owned-token', 'com.docker.compose.project' => 'owned-project' }
    owner = instance_double(described_class::Ownership, token: 'owned-token', read: { 'projects' => ['owned-project'], 'resources' => [] })
    resource = described_class::VolumeResource.new({ 'Name' => 'owned-project_foreign_data', 'Labels' => labels }, owner)
    expect { resource.verify }.to raise_error(described_class::Error, 'Unexpected labelled Docker resource')
  end

  it 'refuses a substituted registered Docker container identity' do
    labels = { described_class::LABEL => 'owned-token', 'com.docker.compose.project' => 'owned-project' }
    manifest = { 'projects' => ['owned-project'], 'resources' => [{ 'kind' => 'container', 'name' => 'owned-project-worker-1', 'id' => 'original-id' }] }
    owner = instance_double(described_class::Ownership, token: 'owned-token', read: manifest)
    resource = described_class::ContainerResource.new({ 'Name' => '/owned-project-worker-1', 'Id' => 'substituted-id', 'Config' => { 'Labels' => labels } }, owner)
    expect { resource.verify }.to raise_error(described_class::Error, 'Registered Docker identity changed')
  end

  it 'records an allowed worker SDK stub separately from provider transport' do
    Dir.mktmpdir('consumer-smoke-aws', File.realpath(Dir.tmpdir)) do |base|
      events = [{ 'kind' => 'sdk_request', 'phase' => 'worker' }, { 'kind' => 'stub_handled', 'phase' => 'worker' }]
      File.write(File.join(base, 'aws.jsonl'), "#{events.map { |event| JSON.generate(event) }.join("\n")}\n")
      result = described_class::AwsEvidence.new(base).verify
      expect(result.fetch('aws_counts').values_at('sdk_request', 'stub_handled', 'provider_transport_attempt')).to eq([1, 1, 0])
      expect(result.fetch('aws_observed_until')).to eq('actual_web_worker_stop')
    end
  end

  it 'rejects setup SDK activity even when transport was stubbed' do
    Dir.mktmpdir('consumer-smoke-aws-setup', File.realpath(Dir.tmpdir)) do |base|
      File.write(File.join(base, 'aws.jsonl'), "#{JSON.generate('kind' => 'sdk_request', 'phase' => 'setup')}\n")
      expect { described_class::AwsEvidence.new(base).verify }.to raise_error(described_class::Error, 'AWS lookup/transport tripwire reached')
    end
  end

  describe 'native socket tripwire' do
    def with_socket_tripwire
      Dir.mktmpdir('consumer-smoke-socket', File.realpath(Dir.tmpdir)) do |base|
        relative = 'test/runtime/consumer_smoke/aws_tripwire.rb'
        fixture = File.join(base, relative)
        evidence = File.join(base, 'tmp/consumer-smoke-evidence')
        FileUtils.mkdir_p([File.dirname(fixture), evidence])
        FileUtils.copy_file(File.expand_path("../../#{relative}", __dir__), fixture)
        environment = SmokeConsumer.environment.merge(
          'BUNDLE_GEMFILE' => File.expand_path('../../Gemfile', __dir__), 'BUNDLE_PATH' => Bundler.settings.path.base_path.to_s,
          'BUNDLE_FROZEN' => 'true', 'CONSUMER_SMOKE_EVIDENCE' => evidence,
          'CONSUMER_SMOKE_PHASE' => 'web', 'CONSUMER_SMOKE_TOKEN' => SecureRandom.hex(16)
        )
        yield fixture, evidence, environment
      end
    end

    def native_listener_script
      <<~RUBY
        require ARGV.fetch(0)
        begin
          server = TCPServer.new('0.0.0.0', 0)
          client = TCPSocket.new('127.0.0.1', server.addr[1], connect_timeout: 1)
          accepted = server.accept_nonblock
          client.write('listener')
          raise 'Missing native listener payload' unless accepted.read(8) == 'listener'
          puts 'native listener accepted'
        ensure
          accepted&.close
          client&.close
          server&.close
        end
      RUBY
    end

    def native_puma_script
      <<~RUBY
        require ARGV.fetch(0)
        require 'puma'
        require 'puma/binder'
        require 'puma/log_writer'
        binder = Puma::Binder.new(Puma::LogWriter.stdio, { max_threads: 1, workers: 0, rack_url_scheme: 'http' })
        begin
          server = binder.add_tcp_listener('0.0.0.0', 0)
          client = TCPSocket.new('127.0.0.1', server.addr[1], connect_timeout: 1)
          accepted = server.accept_nonblock
          client.write('puma')
          raise 'Missing native Puma payload' unless accepted.read(4) == 'puma'
          puts 'native Puma listener accepted'
        ensure
          accepted&.close
          client&.close
          binder.close
        end
      RUBY
    end

    it 'allows a genuine wildcard TCPServer listener and keyword loopback client' do
      with_socket_tripwire do |fixture, evidence, environment|
        output, status = SmokeConsumer::Command.new(timeout: 15).capture(RbConfig.ruby, '-e', native_listener_script, fixture, env: environment, timeout: 10)
        expect(status.success?).to be(true), output
        expect(output).to eq("native listener accepted\n")
        expect(described_class::AwsEvidence.new(evidence).verify.fetch('aws_counts').fetch('socket_attempt')).to eq(0)
      end
    end

    it 'allows the real Puma binder to accept a loopback client on its wildcard listener' do
      with_socket_tripwire do |fixture, evidence, environment|
        output, status = SmokeConsumer::Command.new(timeout: 15).capture(RbConfig.ruby, '-e', native_puma_script, fixture, env: environment, timeout: 10)
        expect(status.success?).to be(true), output
        expect(output).to eq("native Puma listener accepted\n")
        expect(described_class::AwsEvidence.new(evidence).verify.fetch('aws_counts').fetch('socket_attempt')).to eq(0)
      end
    end

    it 'still blocks a wildcard outbound TCPSocket before a native connect' do
      with_socket_tripwire do |fixture, evidence, environment|
        script = <<~RUBY
          require ARGV.fetch(0)
          begin
            TCPSocket.new('0.0.0.0', 1, connect_timeout: 1)
            abort 'Outbound connection was not refused'
          rescue ConsumerSmokeAws::Blocked
            puts 'outbound refused'
          end
        RUBY
        output, status = SmokeConsumer::Command.new(timeout: 15).capture(RbConfig.ruby, '-e', script, fixture, env: environment, timeout: 10)
        expect(status.success?).to be(true), output
        expect(output).to eq("outbound refused\n")
        events = File.readlines(File.join(evidence, 'aws.jsonl')).map { |line| JSON.parse(line) }
        expect(events.count { |event| event.values_at('kind', 'phase', 'blocked') == ['socket_attempt', 'web', true] }).to eq(1)
      end
    end
  end

  it 'accepts an already written cleanup acknowledgement without probing a departed child first' do
    Dir.mktmpdir('consumer-smoke-ack', File.realpath(Dir.tmpdir)) do |base|
      owner = described_class::Ownership.create(base, timeout: 5)
      owner.write_once('cleanup.json', 'token' => owner.token, 'clean' => true)
      allow(Process).to receive(:waitpid)
      expect(described_class::AuthorityReceipt.new(owner, 'cleanup.json').await(1, 999_999).fetch('clean')).to be(true)
      expect(Process).not_to have_received(:waitpid)
    end
  end

  def with_owned_compose
    Dir.mktmpdir('consumer-smoke-compose', File.realpath(Dir.tmpdir)) do |base|
      FileUtils.copy_file(File.expand_path('../../compose.yaml', __dir__), File.join(base, 'compose.yaml'))
      owner = instance_double(described_class::Ownership, token: 'owned-token')
      command = instance_double(described_class::Command, call: ['', nil])
      target = described_class::ConsumerTarget.new(path: base, project: 'owned-project', ownership: owner, command: command,
                                                   environment: { 'PATH' => '/declared/tool/path' }, repository: 'CodySwannGT/railsstarter')
      database = described_class::LocalDatabase.new(target, instance_double(described_class::ComposeRuntime))
      described_class::ComposeConfiguration.new(target, database).write
      yield YAML.safe_load_file(File.join(base, 'compose.smoke.yml'), aliases: true)
    end
  end

  it 'configures actual compose services with one owned image and explicit offline boundaries' do
    with_owned_compose do |config|
      applications = config.fetch('services').values_at('web', 'worker', 'db-prepare')
      expect(applications.map { |service| service.fetch('image') }.uniq).to eq(['owned-project-app:local'])
      expect(applications.map { |service| service.fetch('environment').values_at('AWS_BOOTSTRAP_ENABLED', 'AWS_EC2_METADATA_DISABLED', 'DATABASE_IAM_AUTH') }).to all(eq(%w[false true false]))
      expect(applications.map { |service| service.fetch('environment').fetch('RUBYOPT') }).to all(include('consumer_smoke/aws_tripwire.rb'))
      expect(applications.map { |service| service.key?('env_file') }).to eq([false, false, false])
      expect(config.values_at('volumes', 'networks').map { |section| section.values.first.fetch('labels') }).to all(eq(described_class::LABEL => 'owned-token'))
    end
  end

  it 'points every actual Compose application phase at the private evidence directory' do
    with_owned_compose do |config|
      applications = config.fetch('services').values_at('web', 'worker', 'db-prepare')
      expect(applications.map { |service| service.fetch('environment').fetch('CONSUMER_SMOKE_EVIDENCE') }).to all(eq('/rails/tmp/consumer-smoke-evidence'))
    end
  end

  it 'requires both actual job identifiers and a finished nonfailed queue record' do
    identity = { 'job_id' => '12345678-1234-1234-1234-123456789abc', 'provider_id' => 42 }
    job = described_class::EnqueuedJob.new("boot log\nCONSUMER_JOB=#{JSON.generate(identity)}\n")
    statement = job.completion_sql('named_consumer')
    expect(statement).to include('named_consumer_queue', 'j.id=42', "j.active_job_id='12345678-1234-1234-1234-123456789abc'", 'j.finished_at IS NOT NULL', 'NOT EXISTS',
                                 'solid_queue_failed_executions')
    expect { described_class::EnqueuedJob.new('enqueue failed') }.to raise_error(described_class::Error, 'No actual enqueued job identity')
  end

  context 'with process boundary corrections' do
    def independent_process(pid)
      output, error, status = Open3.capture3('/bin/ps', '-o', 'pid=,lstart=,stat=', '-p', pid.to_s)
      return nil if status.exitstatus == 1 && output.empty? && error.empty?
      raise 'Independent observer failed' unless status.success? && error.empty? && output.split.size == 7

      output.split
    end

    def await_actual_absence(pid)
      described_class::Deadline.new(3).poll('Actual PID absence was not established') { independent_process(pid).nil? }
    end

    def dispose_nonce_process(row)
      observation = independent_process(row.fetch('pid'))
      return unless observation
      raise 'Nonce-owned PID birth changed; signal refused' unless observation[1...-1].join(' ') == row.fetch('birth')

      Process.kill('TERM', row.fetch('pid')) unless observation.last.start_with?('Z')
      await_actual_absence(row.fetch('pid'))
    end

    def exited_leader_script
      <<~CHILD
        require 'json'; require 'open3'
        fork do
          text, = Open3.capture2('/bin/ps', '-o', 'lstart=', '-p', Process.pid.to_s)
          File.write(ARGV[0], JSON.generate(pid: Process.pid, leader: Process.ppid, group: Process.getpgrp, birth: text.split.join(' '), nonce: ARGV[1]))
          sleep 20
        end
        sleep 0.01 until File.file?(ARGV[0])
        exit! 0
      CHILD
    end

    it 'cleans an inherited-pipe grandchild after its leader exits and is reaped' do
      Dir.mktmpdir('consumer-exited-leader', File.realpath(Dir.tmpdir)) do |base|
        file = File.join(base, 'nonce-process.json')
        nonce = SecureRandom.hex(16)
        script = exited_leader_script
        expect { described_class::Command.new(timeout: 5).call(RbConfig.ruby, '-e', script, file, nonce, timeout: 0.8) }.to raise_error(described_class::Error, /deadline exceeded/)
        row = JSON.parse(File.read(file))
        expect(row.fetch('nonce')).to eq(nonce)
        await_actual_absence(row.fetch('pid'))
        await_actual_absence(row.fetch('leader'))
        await_actual_absence(row.fetch('group'))
      ensure
        dispose_nonce_process(JSON.parse(File.read(file))) if File.file?(file)
      end
    end

    it 'refuses an unavailable observer while an independently observed owned PID is live' do
      pid = fork { sleep 20 }
      identity = described_class::Ownership.identity_for(pid)
      original = ENV.fetch('PATH')
      ENV['PATH'] = '/deliberately-absent-consumer-observer'
      expect { described_class::Ownership.alive?(identity) }.to raise_error(described_class::Error)
    ensure
      ENV['PATH'] = original if original
      expect(independent_process(pid)).not_to be_nil
      Process.kill('TERM', pid)
      Process.waitpid(pid)
      await_actual_absence(pid)
    end

    def with_observer_fixture(body, executable: true)
      Dir.mktmpdir('consumer-observer-fault', File.realpath(Dir.tmpdir)) do |base|
        file = File.join(base, 'ps')
        File.write(file, "#!#{RbConfig.ruby}\n#{body}\n", mode: 'w', perm: 0o600)
        File.chmod(0o700, file) if executable
        original = ENV.fetch('PATH')
        ENV['PATH'] = base
        yield base
      ensure
        ENV['PATH'] = original if original
      end
    end

    it 'requires positive census absence after a child is actually reaped' do
      pid = fork { sleep 0.3 }
      identity = described_class::Ownership.identity_for(pid)
      Process.waitpid(pid)
      expect(described_class::Ownership.alive?(identity)).to be(false)
      expect(described_class::ProcessCensus.observe.process(pid).absent?).to be(true)
      expect(independent_process(pid)).to be_nil
    end

    it 'distinguishes an observed zombie from actual PID absence' do
      pid = fork { sleep 0.3 }
      identity = described_class::Ownership.identity_for(pid)
      described_class::Deadline.new(3).poll('Zombie was not observed') { independent_process(pid)&.last&.start_with?('Z') }
      expect(described_class::Ownership.alive?(identity)).to be(false)
      expect(described_class::ProcessCensus.observe.process(pid).absent?).to be(false)
    ensure
      Process.waitpid(pid)
      await_actual_absence(pid)
    end

    it 'refuses stale birth authority without signalling the actual live process' do
      pid = fork { sleep 20 }
      identity = described_class::Ownership.identity_for(pid).merge('birth' => 'different former process')
      expect(described_class::ProcessTree.stop([identity])).to eq([])
      expect(independent_process(pid)).not_to be_nil
    ensure
      Process.kill('TERM', pid)
      Process.waitpid(pid)
      await_actual_absence(pid)
    end

    it 'refuses a failed observer rather than declaring the live PID absent' do
      identity = described_class::Ownership.identity_for(Process.pid)
      with_observer_fixture("warn 'deliberate failure'; exit 1") do
        expect { described_class::Ownership.alive?(identity) }.to raise_error(described_class::Error, /observer failed/)
      end
      expect(independent_process(Process.pid)).not_to be_nil
    end

    it 'refuses a permission-denied observer response' do
      identity = described_class::Ownership.identity_for(Process.pid)
      with_observer_fixture("warn 'Permission denied'; exit 2") do
        expect { described_class::Ownership.alive?(identity) }.to raise_error(described_class::Error, /observer failed/)
      end
    end

    it 'refuses a nonexecutable observer' do
      identity = described_class::Ownership.identity_for(Process.pid)
      with_observer_fixture('exit 0', executable: false) do
        expect { described_class::Ownership.alive?(identity) }.to raise_error(described_class::Error, /observer unavailable/)
      end
    end

    it 'refuses malformed successful observer output' do
      identity = described_class::Ownership.identity_for(Process.pid)
      with_observer_fixture("puts 'malformed row'; exit 0") do
        expect { described_class::Ownership.alive?(identity) }.to raise_error(described_class::Error, /Malformed process observer/)
      end
    end

    it 'refuses an empty successful census instead of treating it as absence' do
      identity = described_class::Ownership.identity_for(Process.pid)
      with_observer_fixture('exit 0') do
        expect { described_class::Ownership.alive?(identity) }.to raise_error(described_class::Error, /Incomplete or duplicate/)
      end
    end

    it 'bounds a timed-out observer and proves its owned PID is actually absent' do
      identity = described_class::Ownership.identity_for(Process.pid)
      with_observer_fixture("File.write(File.join(__dir__, 'observer.pid'), Process.pid.to_s); sleep 20") do |base|
        expect { described_class::Ownership.alive?(identity) }.to raise_error(described_class::Error, /observer deadline exceeded/)
        await_actual_absence(Integer(File.read(File.join(base, 'observer.pid'))))
      end
    end

    it 'denies clean acknowledgement and preserves an owned destination when observation fails' do
      Dir.mktmpdir('consumer-observer-cleanup', File.realpath(Dir.tmpdir)) do |base|
        owner = described_class::Ownership.create(base, timeout: 10)
        path, = owner.register_consumer('preserved_consumer')
        Dir.mkdir(path, 0o700)
        with_observer_fixture("warn 'Permission denied'; exit 2") do
          pid = fork { described_class::CleanupAuthority.detached_watch(owner) }
          expect { described_class::CleanupAuthority.finish(owner, pid) }.to raise_error(described_class::Error, /Owned cleanup failed/)
        end
        expect(JSON.parse(File.read(File.join(owner.root, 'cleanup.json'))).fetch('clean')).to be(false)
        expect(File.directory?(path)).to be(true)
      end
    end

    it 'authenticates command group UID and group ID in the signed manifest' do
      Dir.mktmpdir('consumer-group-signature', File.realpath(Dir.tmpdir)) do |base|
        owner = described_class::Ownership.create(base, timeout: 10)
        described_class::Command.new(timeout: 5, ownership: owner).call(RbConfig.ruby, '-e', 'exit 0')
        file = File.join(owner.root, 'manifest.json')
        original = File.read(file)
        %w[pgid uid].each do |field|
          data = JSON.parse(original)
          data.fetch('processes').first[field] += 1
          File.write(file, JSON.generate(data))
          expect { owner.read }.to raise_error(described_class::Error, 'Process ownership changed')
        end
      end
    end

    it 'refuses the caller process rather than signalling its shared group' do
      identity = described_class::Ownership.identity_for(Process.pid)
      expect { described_class::ProcessTree.stop([identity]) }.to raise_error(described_class::Error, 'Caller process refused')
      expect(independent_process(Process.pid)).not_to be_nil
    end

    def post_freeze_observer
      <<~OBSERVER
        count = File.open(File.join(__dir__, 'count'), File::RDWR | File::CREAT, 0600) do |file|
          file.flock(File::LOCK_EX)
          number = file.read.to_i + 1
          file.rewind; file.write(number.to_s); file.truncate(file.pos)
          number
        end
        if count == 5
          warn 'deliberate post-freeze observer failure'
          exit 2
        end
        exec '/bin/ps', *ARGV
      OBSERVER
    end

    it 'propagates a post-freeze observer failure while retaining bounded guardian cleanup' do
      body = post_freeze_observer
      with_observer_fixture(body) do |base|
        file = File.join(base, 'group.json')
        script = "require 'json'; File.write(ARGV[0], JSON.generate(group: Process.getpgrp)); exit 0"
        expect { described_class::Command.new(timeout: 5).call(RbConfig.ruby, '-e', script, file, timeout: 2) }.to raise_error(described_class::Error, /observer failed/)
        await_actual_absence(JSON.parse(File.read(file)).fetch('group'))
      end
    end

    it 'refuses UID or group authority mismatch instead of declaring a same-birth PID nonrunning' do
      identity = described_class::ProcessCensus.observe.process(Process.pid).group_identity
      %w[uid pgid].each do |field|
        changed = identity.merge(field => identity.fetch(field) + 1)
        expect { described_class::Ownership.alive?(changed) }.to raise_error(described_class::Error, 'Owned process group or UID changed')
      end
      expect(independent_process(Process.pid)).not_to be_nil
    end

    it 'retains a real signalled child status without treating it as success' do
      _, status = described_class::Command.new(timeout: 5).capture(RbConfig.ruby, '-e', "Process.kill('TERM', Process.pid)", timeout: 2)
      expect(status.exitstatus).to be_nil
      expect(status.termsig).to eq(Signal.list.fetch('TERM'))
      expect(status.success?).to be(false)
    end

    def observer_row(identity, state)
      "#{identity.fetch('pid')} #{Process.pid} #{Process.getpgrp} #{Process.uid} #{identity.fetch('birth')} #{state}"
    end

    it 'keeps an indeterminate owned state present and refuses a nonrunning conclusion' do
      pid = fork { sleep 20 }
      identity = described_class::Ownership.identity_for(pid)
      caller_identity = described_class::Ownership.identity_for(Process.pid)
      rows = [observer_row(caller_identity, 'R'), observer_row(identity, '?')].join("\n")
      with_observer_fixture("puts #{rows.inspect}") do
        expect(described_class::Ownership.alive?(caller_identity)).to be(true)
        expect(described_class::ProcessCensus.observe.process(pid).absent?).to be(false)
        expect { described_class::Ownership.alive?(identity) }.to raise_error(described_class::Error, /indeterminate/)
      end
    ensure
      Process.kill('TERM', pid)
      Process.waitpid(pid)
      await_actual_absence(pid)
    end

    it 'refuses a live sibling in the callers shared group without signalling it' do
      pid = fork { sleep 20 }
      identity = described_class::ProcessCensus.observe.process(pid).group_identity
      expect { described_class::ProcessTree.stop([identity]) }.to raise_error(described_class::Error, /unowned command group refused/)
      expect(independent_process(pid)).not_to be_nil
    ensure
      Process.kill('TERM', pid)
      Process.waitpid(pid)
      await_actual_absence(pid)
    end

    def foreign_uid_observer(child)
      <<~OBSERVER
        require 'open3'
        output, error, status = Open3.capture3('/bin/ps', *ARGV)
        raise 'actual observer failed' unless status.success? && error.empty?
        output.each_line do |line|
          fields = line.split
          fields[3] = '0' if fields.first == '#{child}'
          puts fields.join(' ')
        end
      OBSERVER
    end

    def start_dedicated_sleeping_group(file)
      fork do
        Process.setsid
        child = fork { sleep 20 }
        File.write(file, JSON.generate(child: child), mode: 'w', perm: 0o600)
        sleep 20
        described_class::ForkBoundary.finish(0)
      end
    end

    def with_dedicated_sleeping_group
      Dir.mktmpdir('consumer-foreign-uid', File.realpath(Dir.tmpdir)) do |base|
        file = File.join(base, 'children.json')
        pid = start_dedicated_sleeping_group(file)
        described_class::Deadline.new(3).poll('Dedicated fixture missing') { File.file?(file) }
        identity = described_class::ProcessCensus.observe.process(pid).group_identity
        child = JSON.parse(File.read(file)).fetch('child')
        yield pid, identity, child
      ensure
        described_class::ProcessTree.stop([identity]) if identity
        Process.waitpid(pid) if pid
        await_actual_absence(child) if child
      end
    end

    it 'refuses live foreign UID authority and resumes only its authenticated stopped ancestor' do
      with_dedicated_sleeping_group do |pid, identity, child|
        with_observer_fixture(foreign_uid_observer(child)) do
          expect { described_class::ProcessTree.stop([identity]) }.to raise_error(described_class::Error, 'Foreign UID in command group')
          expect(independent_process(pid).last).not_to start_with('T')
        end
      end
    end
  end
end
