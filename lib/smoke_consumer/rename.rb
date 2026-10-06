# frozen_string_literal: true

require 'rubygems/package'
require 'stringio'

module SmokeConsumer
  # Export only an accepted Git tree. Rename explicit placeholders inside that owned tree.
  class Rename
    # Top-level private, dependency, Git, and generated directories omitted from exported consumers.
    EXCLUDED = %w[.lisa .claude .codex .agents .entire .aws .bundle node_modules].freeze
    # Explicit file allowlist for identity replacement; unrelated source files are untouched.
    PLACEHOLDERS = %w[
      config/application.rb app/views/home/index.html.erb app/views/layouts/application.html.erb
      app/views/pwa/manifest.json.erb spec/requests/home_spec.rb
      spec/jobs/publish_cloud_watch_metrics_job_spec.rb spec/fixtures/runtime/acceptance.json
      package.json package-lock.json
      wiki/lisa-wiki.config.json wiki/start-here.md wiki/index.md wiki/log.md
      wiki/schema/llm-wiki-contract.md config/deploy.yml config/storage.yml
      config/initializers/opentelemetry.rb app/jobs/publish_cloud_watch_metrics_job.rb
      sonar-project.properties bin/deploy-staging
    ].freeze

    # Export the accepted tar into an absent private destination.
    # @param archive [String] accepted tar bytes
    # @param destination [String] absent private export directory
    # @param source [String, nil] resolved Git source identity required in the metadata header
    # @return [void]
    def self.export(archive, destination, source: nil)
      ArchiveExport.new(archive, destination, source: source).write
    end

    # Rename admitted placeholders and Lisa repository identity in the exported tree.
    # @param root [String] consumer or ownership root path
    # @param name [String] safe consumer machine name
    # @param repository [String] validated owner/repository identity
    # @return [Hash{String => Object}]
    def self.apply(root, name, repository)
      new(root, name, repository).apply
    end

    # Store the consumer root, machine name, display name, module name, and repository identity.
    # @param root [String] consumer or ownership root path
    # @param name [String] safe consumer machine name
    # @param repository [String] validated owner/repository identity
    def initialize(root, name, repository)
      @root = root
      @name = name
      @repository = repository
      @words = name.split('_').map(&:capitalize)
    end

    # Apply the explicit path allowlist and return the local rename receipt.
    # @return [Hash{String => Object}]
    def apply
      PLACEHOLDERS.each { |relative| rename_file(relative) }
      config_path = File.join(@root, '.lisa.config.json')
      config = JSON.parse(File.read(config_path))
      config.fetch('github')['org'], config.fetch('github')['repo'] = @repository.split('/')
      File.write(config_path, "#{JSON.pretty_generate(config)}\n")
      result
    end

    private

    # Describe the renamed identity while explicitly leaving provider-gate proof false.
    # @return [Hash{String => Object}]
    def result
      { 'name' => @name, 'module' => @words.join,
        'repository_identity' => @repository, 'provider_binding' => nil,
        'provider_gate_verified' => false, 'reason' => 'Disposable local copy; no provider repository/leaf/backlink created or forged' }
    end

    # Replace identity placeholders in an existing allowlisted file.
    # @param relative [String] allowlisted path relative to the consumer root
    # @return [void]
    def rename_file(relative)
      path = File.join(@root, relative)
      return unless File.file?(path)

      text = File.read(path).gsub('Your Project', @words.join(' ')).gsub('your-project', @name.tr('_', '-')).gsub('your-org', @repository.split('/').first)
      text = text.sub(/module App\b/, "module #{@words.join}") if relative == 'config/application.rb'
      File.write(path, text)
    end
  end

  # Exports an accepted tar into a new private destination, filtering sensitive paths.
  class ArchiveExport
    # Retain accepted tar bytes and the destination path for exclusive export.
    # @param archive [String] accepted tar bytes
    # @param destination [String] absent private export directory
    # @param source [String, nil] resolved Git source identity required in the metadata header
    def initialize(archive, destination, source: nil)
      @archive = archive
      @destination = destination
      @metadata = GitArchiveMetadata.new(source)
    end

    # Create a new private destination and stream admitted tar entries into it.
    # @return [void]
    # @raise [Error] destination already exists or is a symlink
    def write
      raise Error, 'Preexisting or symlinked destination refused' if File.exist?(@destination) || File.symlink?(@destination)

      Dir.mkdir(@destination, 0o700)
      Gem::Package::TarReader.new(StringIO.new(@archive)) { |tar| write_entries(tar) }
    end

    private

    # Skip excluded paths and write each admitted tar entry.
    # @param tar [Gem::Package::TarReader] accepted archive reader
    # @return [void]
    def write_entries(tar)
      tar.each_with_index do |entry, index|
        next if @metadata.consume(entry, index)

        name = entry.full_name
        next if ArchivePath.new(name).excluded?

        ArchiveEntry.new(entry, File.join(@destination, name)).write
      end
      @metadata.require_source
    end
  end

  # Git's global PAX comment identifies the source without granting filesystem overrides.
  class GitArchiveMetadata
    # Retain an optional accepted identity; synthetic regular-file archives may omit metadata.
    # @param source [String, nil] exact resolved Git object identity
    def initialize(source)
      accepted = case source
                 when NilClass then true
                 when String then source.match?(/\A(?:[a-f0-9]{40}|[a-f0-9]{64})\z/)
                 else false
                 end
      raise Error, 'Invalid archive source identity' unless accepted

      @source = source || ''
      @seen = false
    end

    # Consume only the first bounded Git comment, never PAX path/link/mode/owner extensions.
    # @param entry [Gem::Package::TarReader::Entry] current tar entry
    # @param index [Integer] original archive entry position
    # @return [Boolean] whether the metadata entry was consumed
    def consume(entry, index)
      header = entry.header
      return false unless header.typeflag == 'g'

      raise Error, 'Unsupported Git archive metadata' unless index.zero? && !@seen && entry.full_name == 'pax_global_header' && [52, 76].include?(header.size)

      body = entry.read
      record = /\A([0-9]{2}) comment=([a-f0-9]{40}|[a-f0-9]{64})\n\z/.match(body)
      raise Error, 'Git archive source metadata differs' unless record && record[1].to_i == body.bytesize && (@source.empty? || record[2] == @source)

      @seen = true
    end

    # Genuine consumer exports require the accepted commit's metadata, not merely a file-only tar.
    # @return [void]
    def require_source
      raise Error, 'Git archive source metadata missing' if !@source.empty? && !@seen
    end
  end

  # Validates archive paths and identifies excluded private or credential-bearing entries.
  class ArchivePath
    # Parse the archive-relative path and retain its components for escape/exclusion checks.
    # @param name [String] archive member path
    def initialize(name)
      @path = Pathname.new(name)
      @parts = @path.each_filename.to_a
    end

    # Reject escaping paths and identify excluded private entries.
    # @return [Boolean]
    # @raise [Error] archive path escapes the destination
    def excluded?
      raise Error, 'Unsafe archive path' if @path.absolute? || @parts.include?('..')

      first = @parts.first
      Rename::EXCLUDED.include?(first) || first.start_with?('.env') ||
        @parts.any? { |part| part.match?(/\A(?:work-item-context\.md|aws_credentials.*|\.lisa\.config\.local\.json|id_rsa|id_ed25519|master\.key|.*\.pem|.*\.key)\z/) }
    end
  end

  # Writes directories, regular files, and the single admitted worker Dockerfile alias.
  class ArchiveEntry
    # Retain one tar entry, its destination path, and its header for type/mode checks.
    # @param entry [Gem::Package::TarReader::Entry] current accepted archive entry
    # @param path [String] owned filesystem path
    def initialize(entry, path)
      @entry = entry
      @path = path
      @header = entry.header
    end

    # Write the entry according to its admitted directory, alias, or regular-file type.
    # @return [void]
    # @raise [Error] archive entry type is unsupported
    def write
      if @entry.directory?
        FileUtils.mkdir_p(@path, mode: 0o700)
      elsif @header.typeflag == '2'
        write_alias
      elsif @entry.file?
        write_file
      else
        raise Error, 'Unsupported archive entry'
      end
    end

    private

    # Create only the worker Dockerfile alias pointing to Dockerfile.local.
    # @return [void]
    # @raise [Error] alias is not the admitted worker Dockerfile link
    def write_alias
      raise Error, 'Unsafe archive symlink' unless @entry.full_name == 'worker.Dockerfile.local' && @header.linkname == 'Dockerfile.local'

      File.symlink('Dockerfile.local', @path)
    end

    # Exclusively copy file bytes with owner-only read/write or executable permissions.
    # @return [void]
    def write_file
      FileUtils.mkdir_p(File.dirname(@path), mode: 0o700)
      mode = @header.mode.nobits?(0o111) ? 0o600 : 0o700
      File.open(@path, File::WRONLY | File::CREAT | File::EXCL, mode) { |file| IO.copy_stream(@entry, file) }
    end
  end
end
