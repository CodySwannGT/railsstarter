# frozen_string_literal: true

module SmokeConsumer
  # Pairs an official release URL with the SHA-256 digest required before extraction.
  class ReleaseArchive
    attr_reader :url

    # Require an official 64-character SHA-256 digest before retaining its archive URL.
    # @param url [String] official release archive URL
    # @param checksum [String] 64-character official SHA-256 digest
    # @raise [Error] official SHA-256 digest is absent or malformed
    def initialize(url, checksum)
      raise Error, 'Essential prerequisite: official release digest unavailable' unless checksum&.match?(/\A[a-f0-9]{64}\z/)

      @url = url
      @checksum = checksum
    end

    # Require the downloaded file's SHA-256 to match the official expected digest.
    # @param file [String] owned downloaded archive path
    # @return [void]
    # @raise [Error] archive digest differs
    def verify(file)
      raise Error, 'Essential prerequisite: release digest mismatch' unless Digest::SHA256.file(file).hexdigest == @checksum
    end
  end

  # Every current? is an actual new executable probe, including after preparation.
  class VersionedTool
    # Retain bounded command execution, accepted version, mutable environment, and private HOME.
    # @param command [Command] bounded argv executor
    # @param version [String] accepted exact semantic version
    # @param environment [Hash{String => String}] explicit isolated child environment
    # @param home [String] private tool-preparation HOME
    def initialize(command, version, environment, home)
      @command = command
      @version = version
      @environment = environment
      @home = home
    end

    # Require an exact semantic version, provision only if needed, and probe it again.
    # @return [void]
    # @raise [Error] version contract is unsupported or exact tool is unavailable
    def prepare
      valid = @version.is_a?(String) && @version.match?(/\A\d+\.\d+\.\d+\z/)
      raise Error, "Essential prerequisite: unsupported #{self.class::NAME} engine contract #{@version}" unless valid

      provision unless current?
      verify_current
    end

    private

    attr_reader :command, :version, :environment, :home

    # Run a fresh version command and compare its successful output to the exact accepted version.
    # @return [Boolean]
    def current?
      actual, status = @command.capture(self.class::NAME, '--version', env: @environment, timeout: 10)
      status.success? && actual.strip.delete_prefix('v') == @version
    end

    # Require a fresh successful exact-version probe.
    # @return [void]
    # @raise [Error] actual tool version differs
    def verify_current
      raise Error, "Essential prerequisite: #{self.class::NAME} #{@version}" unless current?
    end

    # Download/extract into private HOME on Linux x86_64 only and prepend the resulting PATH.
    # @return [void]
    # @raise [Error] missing tool cannot be prepared on this platform
    def provision
      name = self.class::NAME
      raise Error, "Essential prerequisite: install #{name} #{@version}; automatic preparation supports Linux x86_64 only" unless RUBY_PLATFORM.include?('x86_64-linux')

      folder = File.join(@home, "#{name}-#{@version}")
      Dir.mkdir(folder, 0o700)
      archive = File.join(folder, 'download')
      download(archive)
      executable_folder = extract(archive, folder)
      @environment['PATH'] = "#{executable_folder}:#{@environment.fetch('PATH')}"
    end

    # Fetch the official archive with bounded curl and verify its digest before extraction.
    # @param file [String] owned downloaded archive path
    # @return [void]
    def download(file)
      archive = release
      @command.call('curl', '--fail', '--silent', '--show-error', '--location', '--max-time', '120', '--output', file, archive.url, env: @environment, timeout: 125)
      archive.verify(file)
    end
  end

  # Prepares the accepted exact Node version from the official Linux x86_64 archive.
  class NodeTool < VersionedTool
    # Executable name used for exact Node version probes.
    NAME = 'node'

    private

    # Read the official Node checksum list and construct the matching archive descriptor.
    # @return [ReleaseArchive]
    def release
      name = "node-v#{version}-linux-x64.tar.xz"
      base = "https://nodejs.org/dist/v#{version}"
      sums, = command.call('curl', '--fail', '--silent', '--show-error', '--max-time', '30', "#{base}/SHASUMS256.txt", env: environment, timeout: 35)
      checksum = sums.lines.find { |line| line.split.last == name }&.split&.first
      ReleaseArchive.new("#{base}/#{name}", checksum)
    end

    # Extract the verified Node tar archive and return its executable directory.
    # @param archive [String] verified archive file path
    # @param folder [String] owned archive extraction directory
    # @return [String]
    def extract(archive, folder)
      command.call('tar', '-xJf', archive, '-C', folder, env: environment, timeout: 30)
      File.join(folder, "node-v#{version}-linux-x64", 'bin')
    end
  end

  # Prepares the accepted exact Bun version using its official release checksum list.
  class BunTool < VersionedTool
    # Executable name used for exact Bun version probes.
    NAME = 'bun'

    private

    # Read the official Bun checksum asset without depending on GitHub's API quota.
    # @return [ReleaseArchive]
    def release
      name = 'bun-linux-x64.zip'
      base = "https://github.com/oven-sh/bun/releases/download/bun-v#{version}"
      sums, = command.call('curl', '--fail', '--silent', '--show-error', '--location', '--max-time', '30', "#{base}/SHASUMS256.txt", env: environment, timeout: 35)
      entries = sums.lines.map(&:split).select { |parts| parts.length == 2 && parts.last == name }
      checksum = entries.one? ? entries.first.first : nil
      ReleaseArchive.new("#{base}/#{name}", checksum)
    end

    # Extract the verified Bun zip archive and return its executable directory.
    # @param archive [String] verified archive file path
    # @param folder [String] owned archive extraction directory
    # @return [String]
    def extract(archive, folder)
      command.call('unzip', '-q', archive, '-d', folder, env: environment, timeout: 30)
      File.join(folder, 'bun-linux-x64')
    end
  end

  # The private HOME must prepare the lock's Bundler without borrowing user-installed gems.
  class BundlerTool < VersionedTool
    # RubyGems executable whose selected version must match the consumer lock.
    NAME = 'bundle'

    # Pin RubyGems' version selection for every subsequent setup and bundle command.
    # @return [void]
    def prepare
      environment['BUNDLER_VERSION'] = version
      super
    end

    private

    # Observe the real selected Bundler, treating absence or a different version as unprepared.
    # @return [Boolean]
    def current?
      output, status = command.capture(NAME, '--version', env: environment, timeout: 10)
      status.success? && output.strip == "Bundler version #{version}"
    end

    # Install only the exact locked Bundler into smoke-owned HOME, retaining system default gems.
    # @return [void]
    # @raise [Error] genuine RubyGems installation fails
    def provision
      folder = File.join(home, 'gems')
      Dir.mkdir(folder, 0o700)
      environment.merge!('GEM_HOME' => folder, 'GEM_PATH' => [folder, Gem.default_dir].join(File::PATH_SEPARATOR),
                         'PATH' => "#{File.join(folder, 'bin')}#{File::PATH_SEPARATOR}#{environment.fetch('PATH')}")
      command.call(RbConfig.ruby, '-S', 'gem', 'install', 'bundler', '--version', version, '--no-document', '--install-dir', folder,
                   '--clear-sources', '--source', 'https://rubygems.org', env: environment, timeout: 125)
    rescue Error
      raise Error, "Essential prerequisite: Bundler #{version} installation failed"
    end
  end

  # Only verified, integrity-qualified release tuples remove the old marker's ambiguity.
  class InstallOnlyLifecycle
    # Exact released install-only script qualified by RELEASES; no generic marker exemption.
    SCRIPT = '[ -n "$CI" ] || LISA_BOOTSTRAP=1 node node_modules/@codyswann/lisa/all/copy-overwrite/scripts/lisa-postinstall.mjs || true'
    # Accepted Lisa versions, registry tarball origins, and integrity tuples.
    RELEASES = [
      ['4.70.1', 'https://registry.npmjs.org/@codyswann/lisa/-/lisa-4.70.1.tgz',
       'sha512-PwclAzApLzJ4Yk2Qn3F5dOySvUGhk3r9AHNCyz6arfrPj18Z07Z2qY7Bss+pVDmsbHkJNWfPxEzJ7tosvVgKMQ=='].freeze,
      ['4.70.2', 'https://registry.npmjs.org/@codyswann/lisa/-/lisa-4.70.2.tgz',
       'sha512-x55lWqlnE52eG/Ha0NNYAs50pxbhe+vYf5XQSgH4CaEtym9gWvJAa5YUJPWt3MfYJSsybp7qmmclxmuaKA/Ceg=='].freeze,
      ['4.70.3', 'https://registry.npmjs.org/@codyswann/lisa/-/lisa-4.70.3.tgz',
       'sha512-It9PqbBhe3CNmfzoJ84kWFcNmzZjnFEUvcsF4XVGxSwrqsy6VUQxqA6AqzLv3zjwu0zb36sf5P9SwJW5GAhMqA=='].freeze,
      ['4.70.4', 'https://registry.npmjs.org/@codyswann/lisa/-/lisa-4.70.4.tgz',
       'sha512-iCIaBMe8zIEwLsAXL4l3cmoAFJSx4NS2eWZDXvjiFdJM0s9egMH4YcF5Yj+kODyNFWHvBwAO7m339Fc1BieXuQ=='].freeze,
      ['4.71.2', 'https://registry.npmjs.org/@codyswann/lisa/-/lisa-4.71.2.tgz',
       'sha512-Z8TEFFqHvNPtF4ZvitMaMPv+FoE0oXqPDejBrW/B/jSIuvCEcQXtX2xfMOyqQ4ld+luqB+bZHX7IaU+ISE5xRg=='].freeze,
      ['4.71.4', 'https://registry.npmjs.org/@codyswann/lisa/-/lisa-4.71.4.tgz',
       'sha512-+oHfoSSa50CELUPaOygJW60vIpENRCcxWahqc6Lt96uWnXR6Mr99jk0WafbaqezuKKsl8jj3/48bUwyHkq0nlQ=='].freeze,
      ['4.71.10', 'https://registry.npmjs.org/@codyswann/lisa/-/lisa-4.71.10.tgz',
       'sha512-f1aYRhtqEZ/Vps3A3GEah4T2ax8pDow6I6C2F5I0hXLwKV80y98+G5MG76bfxdP//+Yei4k187mRXIHkBch+kw=='].freeze,
      ['4.73.0', 'https://registry.npmjs.org/@codyswann/lisa/-/lisa-4.73.0.tgz',
       'sha512-mFuJpE2TjwENrISI2+Qzauj/haHidRBU8bg1/bUM+oDacLA957zTpRSCKXV3xH24PBlXRMGfPAAokCXltawgCg=='].freeze,
      ['4.73.1', 'https://registry.npmjs.org/@codyswann/lisa/-/lisa-4.73.1.tgz',
       'sha512-vIxe8Cp02fFyyhebzQiqC1YPPTbRPDLZlPHzFMdrK6d0jezqcZI39go95Fe1AYGIvgFGMKVFBZ6q3iYeMS9T/Q=='].freeze,
      ['4.73.2', 'https://registry.npmjs.org/@codyswann/lisa/-/lisa-4.73.2.tgz',
       'sha512-gK6ZtrK1vHMnt8ok8KgKdkKmrcoRAmejZwInVY2yAcfGJ2v2D9zb4trHAnRF7KJGh1Dte9DevuAb2ua4AeVnjw=='].freeze,
      ['4.73.4', 'https://registry.npmjs.org/@codyswann/lisa/-/lisa-4.73.4.tgz',
       'sha512-cc0aw3XCwCJIGN2YV94sa6YxZB+qf+mo7oc7rGbqg1DF51ZsPeuZvHq0HFljX7jRUgjdymfIT4zPhADwboRF3g=='].freeze,
      ['4.73.5', 'https://registry.npmjs.org/@codyswann/lisa/-/lisa-4.73.5.tgz',
       'sha512-Ze7NJ6DxPhEInJ/SLDy6VedBQ9IFonoSeyidS4JDGoIZn/kBQfOZ319O9sjGAulaaPGfH0Fis6m/r3SXJIExXw=='].freeze,
      ['4.73.6', 'https://registry.npmjs.org/@codyswann/lisa/-/lisa-4.73.6.tgz',
       'sha512-cEWx1NGAzJW7JSV5YGlHt06mjmPQvDRefYVbgPetIIgIIvSMvXpdmzq7U0X+2g3pSI2+027yYQqb8selN1wX+w=='].freeze
    ].freeze
    # Historical full-apply/bootstrap and suppression markers rejected unless the exact release qualifies.
    APPLYING = %r{LISA_BOOTSTRAP=1|--skip-git-check|--full-apply|2>/dev/null \|\| true|(?:\A|\s)apply(?:\s|\z)}

    # Retain accepted release origin/integrity and postinstall metadata for classification.
    # @param metadata [Hash{String => String, nil}] accepted Ruby/Bundler/Lisa/engine/lifecycle metadata
    def initialize(metadata)
      @metadata = metadata
    end

    # Accept the exact integrity-qualified released tuple or scripts without applying/suppression markers.
    # @return [Boolean]
    def acceptable?
      script = @metadata['postinstall'].to_s
      trusted = RELEASES.include?(@metadata.values_at('lisa', 'lisa_resolved', 'lisa_integrity'))
      return true if trusted && script == SCRIPT

      !script.match?(APPLYING)
    end
  end

  # Validate immutable npm inputs and any Bun lock before choosing the first/repeated route.
  class DependencyCarrier
    # Retain the consumer root for owned-file and dependency-carrier validation.
    # @param root [String] consumer or ownership root path
    def initialize(root)
      @root = root
    end

    # Validate matching npm-v3 inputs and digest them plus any real existing Bun locks.
    # @return [Hash{String => String}]
    # @raise [Error] npm carrier is malformed or inconsistent
    def snapshot
      package = document('package.json')
      lock = document('package-lock.json')
      name = package['name'] if package.is_a?(Hash)
      valid = name.is_a?(String) && !name.empty? && lock.is_a?(Hash) && lock['lockfileVersion'] == 3 && name == lock['name']
      raise Error, 'Essential prerequisite: malformed or mismatched dependency carrier' unless valid

      names = %w[package.json package-lock.json] + bun_locks
      names.zip(names.map { |file| digest(file) }).to_h
    end

    # Choose ordinary Bun import if no lock exists, otherwise the frozen-lockfile route.
    # @return [Array<String>]
    def arguments
      bun_locks.empty? ? %w[bun install] : %w[bun install --frozen-lockfile]
    end

    # Reject changes to any input digest captured before dependency installation.
    # @param snapshot [Hash{String => String}] pre-install carrier digests
    # @return [void]
    # @raise [Error] installation changed an accepted input
    def verify_preserved(snapshot)
      changed = snapshot.any? { |name, expected| digest(name) != expected }
      raise Error, 'Dependency carrier changed during installation' if changed
    end

    # Require installation to leave an actual owned nonempty Bun lock.
    # @return [void]
    # @raise [Error] no actual Bun lock was created
    def require_bun_lock
      raise Error, 'Dependency import created no real Bun lock' if bun_locks.empty?
    end

    private

    # Parse JSON from an owned nonempty regular dependency-carrier file.
    # @param name [String] name used by this operation
    # @return [Object]
    # @raise [Error] carrier JSON is malformed or file is not owned/nonempty/regular
    def document(name)
      JSON.parse(File.read(owned_file(name)))
    rescue JSON::ParserError
      raise Error, 'Essential prerequisite: malformed dependency carrier'
    end

    # Return the SHA-256 digest of an owned nonempty regular carrier file.
    # @param name [String] name used by this operation
    # @return [String]
    def digest(name)
      Digest::SHA256.file(owned_file(name)).hexdigest
    end

    # List present validated bun.lock and bun.lockb carrier names.
    # @return [Array<String>]
    def bun_locks
      %w[bun.lock bun.lockb].select do |name|
        file = File.join(@root, name)
        next false unless File.exist?(file) || File.symlink?(file)

        owned_file(name)
        true
      end
    end

    # Require a nonempty current-user regular file without following a symlink.
    # @param name [String] name used by this operation
    # @return [String]
    # @raise [Error] carrier is linked, foreign, empty, or not a regular file
    def owned_file(name)
      file = File.join(@root, name)
      stat = File.lstat(file) if File.exist?(file) || File.symlink?(file)
      valid = stat&.file? && stat.uid == Process.uid && stat.size.positive?
      raise Error, 'Essential prerequisite: dependency carrier must be an owned regular file' unless valid

      file
    end
  end

  # Carries installed Docker plugins into a private client configuration without registry credentials.
  class InstalledDocker
    # Retain the bounded runner, isolated child environment, and exclusively owned tool HOME.
    # @param command [Command] bounded native argv executor
    # @param environment [Hash{String => String}] isolated child environment
    # @param home [String] exclusively owned tool HOME
    def initialize(command, environment, home)
      @command = command
      @environment = environment
      @home = home
    end

    # Authenticate installed Compose/Buildx and retain only their directories in fresh private config.
    # @return [void]
    def prepare
      before = observation({})
      directory = File.join(@home, 'docker-config')
      Dir.mkdir(directory, 0o700)
      settings = { 'cliPluginsExtraDirs' => before.fetch('plugins').values.map { |plugin| File.dirname(plugin.fetch('path')) }.uniq }
      File.open(File.join(directory, 'config.json'), File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(JSON.generate(settings)) }
      environment = @environment.merge('DOCKER_CONFIG' => directory)
      raise Error, 'Private Docker toolchain identity differs' unless observation(environment) == before

      @environment.merge!('DOCKER_CONFIG' => directory)
    end

    private

    # Only public plugin metadata, literal version output and native daemon identity are observed.
    # @param environment [Hash{String => String}] explicit configuration/environment for this observation
    # @return [Hash{String => Object}]
    def observation(environment)
      plugins = installed_plugins(environment)
      daemon, = @command.call('docker', 'info', '--format', '{{.ID}}', env: environment, timeout: 15)
      raise Error, 'Docker daemon identity is missing' if daemon.strip.empty?

      compose, = @command.call('docker', 'compose', 'version', '--short', env: environment, timeout: 10)
      buildx, = @command.call('docker', 'buildx', 'version', env: environment, timeout: 10)
      { 'plugins' => plugins, 'daemon' => daemon, 'compose' => compose, 'buildx' => buildx }
    end

    # Select only the two required unique plugin records from bounded native metadata.
    # @param environment [Hash{String => String}] explicit client environment
    # @return [Hash{String => Hash}]
    def installed_plugins(environment)
      text, = @command.call('docker', 'info', '--format', '{{json .ClientInfo.Plugins}}', env: environment, timeout: 15)
      rows = JSON.parse(text)
      raise Error, 'Installed Docker plugin metadata is malformed' unless rows.is_a?(Array) && rows.size <= 64 && rows.all?(Hash)

      { 'compose' => selected_plugin(rows, 'compose'), 'buildx' => selected_plugin(rows, 'buildx') }
    end

    # Missing or duplicate metadata never selects an arbitrary executable.
    # @param rows [Array<Hash>] native metadata rows
    # @param name [String] required plugin name
    # @return [Hash{String => String}]
    def selected_plugin(rows, name)
      selected = rows.select { |row| row['Name'] == name }
      raise Error, "Essential prerequisite: unique installed Docker #{name} plugin" unless selected.size == 1

      plugin_identity(selected.fetch(0))
    end

    # Hash actual installed executable bytes rather than copying operator Docker configuration.
    # @param metadata [Hash] native Docker CLI's selected plugin metadata
    # @return [Hash{String => String}]
    def plugin_identity(metadata)
      original = metadata.fetch('Path')
      raise Error, 'Installed Docker plugin path is malformed' unless original.is_a?(String) && original.b.match?(%r{\A/[^\0\r\n]{0,4095}\z}n)

      path = File.realpath(original)
      stat = File.stat(path)
      raise Error, 'Installed Docker plugin is not executable' unless stat.file? && stat.mode.anybits?(0o111)

      { 'path' => path, 'version' => metadata.fetch('Version'), 'sha256' => Digest::SHA256.file(path).hexdigest }
    end
  end

  # Checks installed Lisa version and engines against accepted dependency metadata.
  class InstalledLisa
    # Locate the installed Lisa package metadata inside the consumer dependency tree.
    # @param root [String] consumer or ownership root path
    def initialize(root)
      @file = File.join(root, 'node_modules/@codyswann/lisa/package.json')
    end

    # Require installed Lisa version and Node/Bun engines to match accepted metadata.
    # @param metadata [Hash{String => String, nil}] accepted Ruby/Bundler/Lisa/engine/lifecycle metadata
    # @return [void]
    # @raise [Error] installed metadata is absent, malformed, or differs from the accepted tuple
    def verify(metadata)
      raise Error, 'Essential prerequisite: installed Lisa package is unavailable' unless File.file?(@file)

      package = JSON.parse(File.read(@file))
      engines = package.fetch('engines')
      actual = [package.fetch('version'), engines.fetch('node'), engines.fetch('bun')]
      raise Error, 'Essential prerequisite: installed Lisa differs from accepted lock/toolchain' unless actual == metadata.values_at('lisa', 'node', 'bun')
    rescue JSON::ParserError, KeyError
      raise Error, 'Essential prerequisite: installed Lisa metadata is malformed'
    end
  end

  # First npm import is ordinary; a real existing Bun lock makes every repeated install frozen.
  class DependencyInstall
    # Retain command/root and create the carrier-preservation adapter.
    # @param command [Command] bounded argv executor
    # @param root [String] consumer or ownership root path
    def initialize(command, root)
      @command = command
      @root = root
      @carrier = DependencyCarrier.new(root)
    end

    # Run the selected ordinary/frozen Bun route and verify carrier preservation, real lock, and installed Lisa.
    # @param environment [Hash{String => String}] explicit isolated child environment
    # @param metadata [Hash{String => String, nil}] accepted Ruby/Bundler/Lisa/engine/lifecycle metadata
    # @return [void]
    def call(environment, metadata)
      before = @carrier.snapshot
      @command.call(*@carrier.arguments, env: environment, chdir: @root)
      @carrier.verify_preserved(before)
      @carrier.require_bun_lock
      InstalledLisa.new(@root).verify(metadata)
    end
  end

  # Tools derive from the accepted consumer lock, never an actor's private resolver.
  class Toolchain
    # Extract Ruby, Bundler, Lisa origin/integrity, engines, and postinstall from committed inputs.
    # @param package [Hash] committed package.json document
    # @param lock [Hash] committed npm lock document
    # @param ruby_version [String] committed .ruby-version bytes
    # @param gem_lock [String] committed Gemfile.lock bytes
    # @return [Hash{String => String, nil}]
    # @raise [Error] required accepted lock metadata is missing
    def self.metadata(package, lock, ruby_version, gem_lock)
      lisa = lock.fetch('packages').fetch('node_modules/@codyswann/lisa')
      engines = lisa.fetch('engines')
      { 'ruby' => ruby_version.strip, 'node' => engines.fetch('node'), 'bun' => engines.fetch('bun'),
        'bundler' => gem_lock.match(/BUNDLED WITH\s+(\d+\.\d+\.\d+)/)&.captures&.first,
        'lisa' => lisa.fetch('version'), 'lisa_resolved' => lisa.fetch('resolved'), 'lisa_integrity' => lisa.fetch('integrity'),
        'postinstall' => package.fetch('scripts', {})['postinstall'] }
    rescue KeyError
      raise Error, 'Essential prerequisite: accepted Lisa lock/toolchain metadata is missing'
    end

    # Reject an accepted lifecycle that still performs or suppresses a full Lisa apply.
    # @param metadata [Hash{String => String, nil}] accepted Ruby/Bundler/Lisa/engine/lifecycle metadata
    # @return [void]
    # @raise [Error] lifecycle performs or suppresses full apply
    def self.require_install_only(metadata)
      return if InstallOnlyLifecycle.new(metadata).acceptable?

      raise Error, 'Essential prerequisite: accepted package still runs/suppresses a full Lisa apply in postinstall; adopt the genuine released install-only lifecycle first'
    end

    # Require the actual Ruby interpreter to equal the accepted Ruby version.
    # @param metadata [Hash{String => String, nil}] accepted Ruby/Bundler/Lisa/engine/lifecycle metadata
    # @return [void]
    # @raise [Error] actual Ruby version differs
    def self.require_ruby(metadata)
      expected = metadata.fetch('ruby')
      raise Error, "Essential prerequisite: Ruby #{expected} (actual #{RUBY_VERSION})" unless expected == RUBY_VERSION
    end

    # Retain command, accepted metadata, and private HOME for exact-version preparation.
    # @param command [Command] bounded argv executor
    # @param metadata [Hash{String => String, nil}] accepted Ruby/Bundler/Lisa/engine/lifecycle metadata
    # @param home [String] private tool-preparation HOME
    def initialize(command, metadata, home)
      @command = command
      @metadata = metadata
      @home = home
    end

    # Prepare accepted Node/Bun in private HOME and require exact Bundler before returning its environment.
    # @return [Hash{String => String}]
    def environment
      env = { 'HOME' => @home, 'PATH' => ENV.fetch('PATH', '') }
      self.class.require_ruby(@metadata)
      NodeTool.new(@command, @metadata.fetch('node'), env, @home).prepare
      BunTool.new(@command, @metadata.fetch('bun'), env, @home).prepare
      BundlerTool.new(@command, @metadata.fetch('bundler'), env, @home).prepare
      verify_bundler(env)
      env
    end

    # Only the consumer runtime route needs isolated native Docker/Compose, not generic setup probes.
    # @return [Hash{String => String}] isolated consumer tool environment
    def consumer_environment
      env = environment
      InstalledDocker.new(@command, env, @home).prepare
      env
    end

    private

    # Require actual bundle --version output to equal the accepted Bundler version.
    # @param env [Hash{String => String}] private child environment
    # @return [void]
    # @raise [Error] actual Bundler version differs
    def verify_bundler(env)
      expected = @metadata.fetch('bundler')
      version, = @command.call('bundle', '--version', env: env, timeout: 10)
      raise Error, "Essential prerequisite: Bundler #{expected}" unless version.strip == "Bundler version #{expected}"
    end
  end
end
