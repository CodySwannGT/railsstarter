# frozen_string_literal: true

require 'forwardable'

module SmokeConsumer
  # Rejects group identities that lack their own anchor or share the caller group.
  class GroupAuthority
    # Retain the expected anchor PID and process-group ID for validation.
    # @param identity [Hash{String => Object}] expected observed PID/birth identity and optional group/UID fields
    def initialize(identity)
      @pid = identity.fetch('pid')
      @group = identity.fetch('pgid')
    end

    # Require PID equal to PGID and reject the caller's shared process group.
    # @return [void]
    # @raise [Error] group lacks its anchor or shares the caller group
    def validate
      raise Error, 'Caller or unowned command group refused' unless @group == @pid && @group != Process.getpgrp
    end
  end

  # Every signal requires a new observation; this value retains identity, never liveness.
  class ProcessSignal
    # Retain the observed identity and PID that must be rechecked before each signal.
    # @param identity [Hash{String => Object}] expected observed PID/birth identity and optional group/UID fields
    def initialize(identity)
      @identity = identity
      @pid = identity.fetch('pid')
    end

    # Require a fresh observation to match the expected process identity.
    # @param message [String] error message when identity is no longer live
    # @return [void]
    # @raise [Error] fresh identity does not match
    def require_live(message)
      raise Error, message unless Ownership.alive?(@identity)
    end

    # Send STOP only after a fresh identity check; tolerate disappearance.
    # @return [Hash, nil]
    def stop
      deliver('STOP')
    end

    # Send KILL only after a fresh identity check; tolerate disappearance.
    # @return [Hash, nil]
    def kill
      deliver('KILL')
    end

    # Send CONT only after a fresh identity check; tolerate disappearance.
    # @return [Hash, nil]
    def resume
      deliver('CONT')
    end

    private

    # Refuse the caller PID and signal only a freshly matching identity, tolerating ESRCH.
    # @param signal [String] STOP, KILL, or CONT
    # @return [Hash, nil]
    # @raise [Error] target PID is the caller
    def deliver(signal)
      raise Error, 'Caller process refused' if @pid == Process.pid
      return unless Ownership.alive?(@identity)

      Process.kill(signal, @pid)
      @identity
    rescue Errno::ESRCH
      nil
    end
  end

  # A signed session anchor retains group authority even after its executed child has exited.
  # Roots/members are signalled only after fresh PID/birth/UID/group observations.
  class ProcessTree
    # Freeze roots and descendants, kill them, and resume frozen processes if cleanup fails.
    # @param roots [Array<Hash>] owned observed root identities
    # @return [Array<Hash>]
    def self.stop(roots)
      tree = new
      tree.freeze_roots(roots)
      tree.freeze_descendants
      tree.kill_frozen
    rescue StandardError
      tree.resume_frozen
      raise
    end

    # Retain this isolated guardian anchor and kill its observed descendants, resuming on failure.
    # @param identity [Hash{String => Object}] expected observed PID/birth identity and optional group/UID fields
    # @return [Array<Hash>]
    def self.stop_members(identity)
      tree = new
      tree.retain_self_anchor(identity)
      tree.freeze_descendants
      tree.kill_frozen
    rescue StandardError
      tree.resume_frozen
      raise
    end

    # Create empty tracked identity/group sets and a ten-second cleanup deadline.
    def initialize
      @identities = []
      @groups = []
      @excluded = 0
      @limit = Deadline.new(10)
    end

    # One fresh census skips positively absent roots; it never authorizes a signal.
    # Validate every group first, then retain each present root's independent signal checks.
    # @param roots [Array<Hash>] owned observed root identities
    # @return [void]
    def freeze_roots(roots)
      census = ProcessCensus.observe
      roots.each do |row|
        @limit.check('Process tree deadline exceeded')
        identity = Ownership.process_identity(row)
        GroupAuthority.new(identity).validate if identity.key?('pgid')
        next if census.process(identity.fetch('pid')).absent?

        freeze_root(identity)
      end
    end

    # Require this process to own its isolated session and retain its group for descendant checks.
    # @param identity [Hash{String => Object}] expected observed PID/birth identity and optional group/UID fields
    # @return [void]
    def retain_self_anchor(identity)
      group = identity.fetch('pgid')
      current_pid = Process.pid
      raise Error, 'Guardian session authority refused' unless identity.fetch('pid') == current_pid && group == current_pid && Process.getsid(0) == group

      ProcessSignal.new(identity).require_live('Guardian process identity changed')

      @excluded = current_pid
      @groups << identity
    end

    # Repeatedly freeze fresh descendants until convergence, with iteration/count bounds.
    # @return [void]
    # @raise [Error] descendants exceed bounds or fail to converge
    def freeze_descendants
      32.times do
        @limit.check('Process tree deadline exceeded')
        unseen = candidates
        return if unseen.empty?

        unseen.each { |row| freeze_identity(row.group_identity) }
        raise Error, 'Process tree exceeded ownership bound' if @identities.size > 256
      end
      raise Error, 'Process tree did not converge'
    end

    # Kill in reverse order and require all frozen identities to be nonrunning before the deadline.
    # @return [Array<Hash>]
    def kill_frozen
      @identities.reverse_each do |identity|
        @limit.check('Process tree deadline exceeded')
        ProcessSignal.new(identity).kill
      end
      Deadline.new(3, ceiling: @limit.expires_at).poll('Owned process remains running') do
        census = ProcessCensus.observe
        @identities.all? { |identity| census.process(identity.fetch('pid')).nonrunning?(identity) }
      end
      @identities
    end

    # Merge fresh child/group observations and return untracked running observations once per PID.
    # @return [Array<ProcessObservation>]
    def candidates
      census = ProcessCensus.observe
      parents = @identities.map { |row| row.fetch('pid') }
      parents << @excluded if @excluded.positive?
      rows = census.children(parents) + @groups.flat_map { |identity| census.group_members(identity) }
      rows.select { |row| row.unseen?(parents) }.uniq(&:pid)
    end

    # Resume every frozen identity after a failed cleanup attempt.
    # @return [void]
    def resume_frozen
      @identities.each { |identity| ProcessSignal.new(identity).resume }
    end

    # Validate any group authority, freeze the root, and retain its isolated group.
    # @param identity [Hash{String => Object}] expected observed PID/birth identity and optional group/UID fields
    # @return [void]
    def freeze_root(identity)
      grouped = identity.key?('pgid')
      GroupAuthority.new(identity).validate if grouped
      return unless freeze_identity(identity)

      retain_group(identity) if grouped
    end

    # Require an isolated session whose ID equals the root group before retaining it.
    # @param identity [Hash{String => Object}] expected observed PID/birth identity and optional group/UID fields
    # @return [void]
    def retain_group(identity)
      group = identity.fetch('pgid')
      raise Error, 'Command session identity changed' unless Process.getsid(group) == group

      @groups << identity
    end

    # STOP a freshly matching process and record it only when the signal identity remains valid.
    # @param identity [Hash{String => Object}] expected observed PID/birth identity and optional group/UID fields
    # @return [Hash, nil] stopped identity, or nil if it disappeared
    def freeze_identity(identity)
      return unless ProcessSignal.new(identity).stop

      @identities << identity
      identity
    end
  end

  # Separates a live matching process from positive absence in one fresh census.
  class ProcessTerminationProof
    extend Forwardable

    # Retain the expected identity and its observation from the supplied fresh census.
    # @param census [ProcessCensus] fresh process observation set
    # @param identity [Hash{String => Object}] expected observed PID/birth identity and optional group/UID fields
    def initialize(census, identity)
      @identity = identity
      @observation = census.process(identity.fetch('pid'))
    end

    # Compare the fresh observation to the expected live process identity.
    # @return [Boolean]
    def live?
      @observation.matches_live?(@identity)
    end

    def_delegator :@observation, :absent?
  end

  # Checks owned Docker labels, project naming, and any registered immutable identifier.
  class DockerResource
    # Retain one actual inspection object and its exclusive ownership authority.
    # @param object [Hash] fresh Docker inspection object
    # @param ownership [Ownership] exclusive validated ownership scope
    def initialize(object, ownership)
      @object = object
      @ownership = ownership
    end

    # Validate token/project labels, admitted names, and recorded immutable ID before removal.
    # @return [void]
    # @raise [Error] token, project, name, or registered ID does not match
    def verify
      manifest = @ownership.read
      project = labels.fetch('com.docker.compose.project')
      raise Error, 'Docker ownership mismatch' unless labels[LABEL] == @ownership.token && manifest.fetch('projects').include?(project)
      raise Error, 'Unexpected labelled Docker resource' unless name.match?(name_pattern(project))

      verify_registered(manifest)
    end

    # Reject an immutable ID change for a previously recorded kind/name resource.
    # @param manifest [Hash] validated ownership manifest
    # @return [void]
    # @raise [Error] registered immutable ID changed
    def verify_registered(manifest)
      key = [self.class::KIND, name]
      registered = manifest.fetch('resources').find { |entry| entry.values_at('kind', 'name') == key }
      raise Error, 'Registered Docker identity changed' if registered && registered['id'] != identifier
    end

    # Build the anchored admitted resource-name pattern for an escaped project name.
    # @param project [String] registered token-bound Compose project
    # @return [Regexp]
    def name_pattern(project)
      /\A#{Regexp.escape(project)}#{self.class::SUFFIX}\z/
    end

    protected

    attr_reader :object

    public

    # Read the inspected immutable Id, falling back to Name when Docker provides no Id.
    # @return [String]
    def identifier
      @object['Id'] || @object.fetch('Name')
    end
  end

  # Validates owned application, database, and preparation container names and labels.
  class ContainerResource < DockerResource
    # Docker resource kind checked against registered ownership records.
    KIND = 'container'
    # Admitted Compose resource-name suffix pattern for this resource kind.
    SUFFIX = '-(web|worker|db-prepare|db)-1'

    # Read labels from the inspected container Config.
    # @return [Hash{String => String}]
    def labels
      object.fetch('Config').fetch('Labels')
    end

    # Normalize Docker's leading slash from the inspected container name.
    # @return [String]
    def name
      object.fetch('Name').delete_prefix('/')
    end
  end

  # Validates the owned MySQL volume name and labels from Docker inspection.
  class VolumeResource < DockerResource
    # Docker resource kind checked against registered ownership records.
    KIND = 'volume'
    # Admitted Compose resource-name suffix pattern for this resource kind.
    SUFFIX = '_mysql_data'

    # Read labels directly from the inspected volume/network object.
    # @return [Hash{String => String}]
    def labels
      object.fetch('Labels')
    end

    # Read the inspected volume/network name.
    # @return [String]
    def name
      object.fetch('Name')
    end
  end

  # Validates the owned default network name and labels from Docker inspection.
  class NetworkResource < VolumeResource
    # Docker resource kind checked against registered ownership records.
    KIND = 'network'
    # Admitted Compose resource-name suffix pattern for this resource kind.
    SUFFIX = '_default'
  end

  # Inventory verification is a new provider read AFTER removal, never a cached pre-read.
  class DockerCollection
    # Retain ownership and bounded Docker command execution for the resource collection.
    # @param ownership [Ownership] exclusive validated ownership scope
    # @param command [Command] bounded argv executor
    def initialize(ownership, command)
      @ownership = ownership
      @command = command
    end

    # Inspect/verify/remove each freshly labeled resource and then prove collection absence.
    # @return [Array<String>]
    def remove_all
      ids = inventory
      ids.each { |identifier| remove(identifier) }
      verify_absent
      ids
    end

    protected

    attr_reader :ownership, :command

    private

    # List current resource identifiers matching the exclusive ownership label.
    # @return [Array<String>]
    def inventory
      text, = @command.call('docker', *self.class::LIST, '--filter', "label=#{LABEL}=#{@ownership.token}", timeout: 10)
      text.split
    end

    # Inspect one actual resource, verify ownership, and invoke its collection's removal argv.
    # @param identifier [String] freshly listed Docker resource ID
    # @return [void]
    def remove(identifier)
      type = self.class
      text, = @command.call('docker', type::KIND, 'inspect', identifier, timeout: 10)
      resource = type::RESOURCE.new(JSON.parse(text).fetch(0), @ownership)
      resource.verify
      @command.call('docker', type::KIND, *type::REMOVE, identifier, timeout: 10)
    end

    # Re-list owned resources and require an empty fresh inventory.
    # @return [void]
    # @raise [Error] owned resources remain
    def verify_absent
      raise Error, "Owned #{self.class::KIND} remains" unless inventory.empty?
    end
  end

  # Verify every immutable identity before a bounded batch removal to avoid repeated Docker startup.
  class ImmutableDockerCollection < DockerCollection
    # Remove a fully verified inventory and independently prove fresh collection absence.
    # @return [Array<String>]
    def remove_all
      ids = inventory
      remove_batch(ids) unless ids.empty?
      verify_absent
      ids
    end

    private

    # Reject ambiguous or abbreviated inventories before any inspection or mutation.
    # @return [Array<String>]
    # @raise [Error] inventory does not contain unique full immutable Docker identities
    def inventory
      ids = super
      valid = ids.uniq == ids && ids.all? { |identifier| identifier.match?(/\A[0-9a-f]{64}\z/) }
      raise Error, 'Docker inventory requires unique full immutable identities' unless valid

      ids
    end

    # Verify the complete inspected set before deleting any of its immutable identities.
    # @param ids [Array<String>] freshly inventoried full immutable Docker identities
    # @return [void]
    def remove_batch(ids)
      type = self.class
      inspected(ids).each { |object| type::RESOURCE.new(object, ownership).verify }
      command.call('docker', type::KIND, *type::REMOVE, *ids, timeout: 10)
    end

    # Require an exact one-to-one immutable identity match from kind-specific inspection.
    # @param ids [Array<String>] freshly inventoried full immutable Docker identities
    # @return [Array<Hash>]
    # @raise [Error] inspection is malformed or differs from the complete inventory
    def inspected(ids)
      text, = command.call('docker', self.class::KIND, 'inspect', *ids, timeout: 10)
      objects = parse_inspection(text)
      raise Error, 'Docker inspection does not match inventory' unless matching_inspection?(objects, ids)

      objects
    end

    # Preserve a malformed JSON response as a failed inventory comparison.
    # @param text [String] native kind-specific inspection output
    # @return [Object, nil] parsed response, or a malformed-response sentinel
    def parse_inspection(text)
      JSON.parse(text)
    rescue JSON::ParserError
      nil
    end

    # Compare actual Id fields only; names cannot substitute for immutable removal authority.
    # @param objects [Object] parsed native inspection response
    # @param ids [Array<String>] complete immutable inventory
    # @return [Boolean]
    def matching_inspection?(objects, ids)
      return false unless objects.is_a?(Array) && objects.all?(Hash)

      inspected_ids = objects.map { |object| object.fetch('Id', nil) }
      count = ids.length
      inspected_ids.length == count && inspected_ids.uniq.length == count &&
        (inspected_ids - ids).empty?
    end
  end

  # Lists and removes only freshly verified containers carrying the ownership label.
  class ContainerCollection < ImmutableDockerCollection
    # Docker resource kind used for live inspection and removal.
    KIND = 'container'
    # Docker argv prefix for listing resources with the exclusive token-label filter.
    LIST = %w[ps --all --quiet --no-trunc].freeze
    # Docker argv prefix for removing a freshly inspected and verified resource.
    REMOVE = %w[rm --force].freeze
    # ContainerResource validator required before invoking removal.
    RESOURCE = ContainerResource
  end

  # Lists and removes only freshly verified volumes carrying the ownership label.
  class VolumeCollection < DockerCollection
    # Docker resource kind used for live inspection and removal.
    KIND = 'volume'
    # Docker argv prefix for listing resources with the exclusive token-label filter.
    LIST = %w[volume ls --quiet].freeze
    # Docker argv prefix for removing a freshly inspected and verified resource.
    REMOVE = ['rm'].freeze
    # VolumeResource validator required before invoking removal.
    RESOURCE = VolumeResource
  end

  # Lists and removes only freshly verified networks carrying the ownership label.
  class NetworkCollection < ImmutableDockerCollection
    # Docker resource kind used for live inspection and removal.
    KIND = 'network'
    # Docker argv prefix for listing resources with the exclusive token-label filter.
    LIST = %w[network ls --quiet --no-trunc].freeze
    # Docker argv prefix for removing a freshly inspected and verified resource.
    REMOVE = ['rm'].freeze
    # NetworkResource validator required before invoking removal.
    RESOURCE = NetworkResource
  end

  # Authorizes one immutable image without adopting foreign aliases or losing failed-build cleanup.
  class OwnedImageIdentity
    # Retain the exclusive owner and its derived project/tag intent.
    # @param ownership [Ownership] validated private ownership scope
    # @param project [String] preregistered token-bound project
    # @param tag [String] derived local app-image tag
    def initialize(ownership, project, tag)
      @ownership = ownership
      @project = project
      @tag = tag
    end

    # Revalidate allocation before inventory or destructive work.
    # @return [Hash] current validated ownership manifest
    # @raise [Error] project was not allocated by this owner
    def manifest
      data = @ownership.read
      raise Error, 'Image outside registered project' unless data.fetch('projects').include?(@project)

      data
    end

    # Return the canonical fresh ID only after all ownership and alias checks.
    # A build may fail before ID registration; the preregistered project still owns its labelled image.
    # @param object [Hash] freshly observed single Docker image
    # @return [String] full immutable image ID
    def verify(object)
      identifier = object['Id']
      raise Error, 'Invalid immutable app image ID' unless identifier.is_a?(String) && identifier.match?(/\Asha256:[a-f0-9]{64}\z/)

      verify_label(object)
      registered = registered_identifier
      raise Error, 'Registered image identity changed' if registered && registered != identifier

      verify_aliases(object)
      identifier
    end

    # Validate any registration before an absent tag can be considered cleaned.
    # @return [String, nil] canonical registered ID, or none for an unfinished build
    # @raise [Error] registration is duplicated, malformed or bound to another project
    def registered_identifier
      entry = registered_entry(manifest)
      return unless entry

      identifier = entry['id']
      valid = identifier.is_a?(String) && identifier.match?(/\Asha256:[a-f0-9]{64}\z/)
      raise Error, 'Registered image identity changed' unless valid && entry['project'] == @project

      identifier
    end

    private

    # Require a typed actual token label, never a name-based ownership guess.
    # @param object [Hash] fresh Docker image object
    # @return [void]
    def verify_label(object)
      config = object['Config']
      labels = config.is_a?(Hash) ? config['Labels'] : nil
      raise Error, 'Unowned app image' unless labels.is_a?(Hash) && labels[LABEL] == @ownership.token
    end

    # An existing registration must be unique and match both ID and project.
    # @param data [Hash] current validated manifest
    # @return [Hash, nil] unique registration, or none when the build failed before registration
    def registered_entry(data)
      entries = data.fetch('resources').select { |entry| entry.values_at('kind', 'name') == ['image', @tag] }
      case entries
      in []
        nil
      in [Hash => entry]
        entry
      else
        raise Error, 'Registered image identity changed'
      end
    end

    # Refuse shared tags and foreign or malformed repository-digest references.
    # @param object [Hash] fresh Docker image object
    # @return [void]
    def verify_aliases(object)
      digests = object['RepoDigests']
      repository = @tag.delete_suffix(':local')
      own_digests = digests.is_a?(Array) && digests.uniq == digests && digests.all? do |digest|
        digest.is_a?(String) && digest.match?(/\A#{Regexp.escape(repository)}@sha256:[a-f0-9]{64}\z/)
      end
      raise Error, 'App image aliases are not exclusively owned' unless object['RepoTags'] == [@tag] && own_digests
    end
  end

  # Removes only a freshly authorized immutable image, preserving untagged parents.
  class OwnedImage
    # Derive the local image tag from the registered project and retain cleanup authority.
    # @param ownership [Ownership] exclusive validated ownership scope
    # @param command [Command] bounded argv executor
    # @param project [String] registered token-bound Compose project
    def initialize(ownership, command, project)
      @ownership = ownership
      @command = command
      @project = project
      @tag = "#{project}-app:local"
    end

    # Remove the exact inspected image without force/pruning, then observe tag and ID absence.
    # @return [void]
    def remove
      identity = OwnedImageIdentity.new(@ownership, @project, @tag)
      registered = identity.registered_identifier
      object = inspect_image
      unless object
        verify_id_absent(registered) if registered
        return
      end

      identifier = identity.verify(object)
      @command.call('docker', 'image', 'rm', '--no-prune', identifier, timeout: 10)
      verify_absent(identifier)
    end

    private

    # Return the actual inspected image or nil only for Docker's explicit no-such-image response.
    # @param target [String] exact tag or immutable image ID to inspect
    # @return [Hash, nil]
    # @raise [Error] Docker failure is not explicit image absence
    def inspect_image(target = @tag)
      text, status = @command.capture('docker', 'image', 'inspect', target, timeout: 10)
      return parse_image(text) if status.success?
      return nil if explicit_absence?(text, status, target)

      raise Error, 'Image inventory unavailable'
    end

    # Accept only the native missing-target response, without other diagnostic lines.
    # @param text [String] combined native stdout/stderr
    # @param status [CommandExit] actual command exit observation
    # @param target [String] exact inspected tag or ID
    # @return [Boolean] positive native absence
    def explicit_absence?(text, status, target)
      expected = ['[]', "Error response from daemon: No such image: #{target}"]
      lines = text.lines.map(&:strip).reject(&:empty?)
      status.exitstatus == 1 && lines.sort == expected.sort
    end

    # A one-target native query cannot legitimately return two objects or an untyped value.
    # @param text [String] successful Docker inspection output
    # @return [Hash] exactly one image object
    # @raise [Error] malformed JSON or unexpected object count/type
    def parse_image(text)
      case decode_image(text)
      in [Hash => object]
        object
      else
        raise Error, 'Malformed image inventory'
      end
    end

    # Decode native JSON without converting a parser failure into absence.
    # @param text [String] successful Docker inspection output
    # @return [Object] parsed response, validated by parse_image
    def decode_image(text)
      JSON.parse(text)
    rescue JSON::ParserError
      raise Error, 'Malformed image inventory'
    end

    # Require separate fresh tag and ID inspections to report absence.
    # @param identifier [String] exact immutable ID used for removal
    # @return [void]
    # @raise [Error] owned image tag remains
    def verify_absent(identifier)
      raise Error, 'App image tag remains or inventory failed' if inspect_image

      verify_id_absent(identifier)
    end

    # An absent tag does not prove that its immutable registered image disappeared.
    # @param identifier [String] validated immutable image ID
    # @return [void]
    # @raise [Error] registered image remains or its inventory cannot be read
    def verify_id_absent(identifier)
      raise Error, 'App image ID remains or inventory failed' if inspect_image(identifier)
    end
  end

  # Securely removes a named consumer path inside its unchanged exclusive ownership root.
  class OwnedConsumerPath
    # Remove independent consumer trees concurrently and propagate failure after every removal settles.
    # @param ownership [Ownership] exclusive validated ownership scope
    # @param paths [Array<String>] separately allocated direct-child consumer paths
    # @return [void]
    # @raise [StandardError] an individual owned-directory removal fails
    def self.remove_all(ownership, paths)
      threads = []
      begin
        paths.each do |path|
          threads << Thread.new do
            new(ownership, path).remove
          rescue StandardError => error
            error
          end
        end
      ensure
        threads.each(&:join)
      end
      failure = threads.map(&:value).find { |result| result.is_a?(StandardError) }
      raise failure if failure
    end

    # Retain ownership and the named consumer path for secure removal checks.
    # @param ownership [Ownership] exclusive validated ownership scope
    # @param path [String] owned filesystem path
    def initialize(ownership, path)
      @ownership = ownership
      @path = path
    end

    # Require a safe direct-child consumer path, remove it securely, and verify positive absence.
    # @return [void]
    # @raise [Error] path is unsafe, linked, or remains after removal
    def remove
      raise Error, 'Unowned consumer path' unless File.dirname(@path) == @ownership.root && File.basename(@path).match?(/\A[a-z][a-z0-9_]{2,39}\z/)
      raise Error, 'Symlinked consumer path' if File.symlink?(@path)

      erase_existing
      raise Error, 'Consumer destination remains' if File.exist?(@path)
    end

    private

    # Securely remove the existing owned consumer directory.
    # @return [void]
    def erase_existing
      FileUtils.remove_entry_secure(@path) if File.exist?(@path) # rubocop:disable Lint/NonAtomicFileOperation -- secure deletion, never rm_rf a substituted path.
    end
  end

  # Acknowledgement/reaping protocol is independent of app resource removal.
  class AuthorityReceipt
    # Derive the named receipt path inside the ownership root.
    # @param ownership [Ownership] exclusive validated ownership scope
    # @param name [String] name used by this operation
    def initialize(ownership, name)
      @ownership = ownership
      @path = File.join(ownership.root, name)
    end

    # Poll a token-root receipt under a deadline, rejecting links and premature authority exit.
    # @param seconds [Numeric] receipt polling limit in seconds
    # @param pid [Integer, nil] process ID; nil disables the optional child-exit check
    # @return [Hash]
    # @raise [Error] receipt deadline expires, authority exits early, or receipt is linked
    def await(seconds, pid = nil)
      Deadline.new(seconds).poll('Cleanup acknowledgement deadline exceeded') do
        ready = File.file?(@path)
        raise Error, 'Cleanup authority exited before acknowledging' if !ready && pid && Process.waitpid(pid, Process::WNOHANG)

        ready
      end
      @ownership.validate
      raise Error, 'Symlinked authority acknowledgement' if File.symlink?(@path)

      JSON.parse(File.read(@path))
    end

    # Verify the watcher token/root/inode/birth receipt and its separate process group.
    # @param pid [Integer] process ID to observe, signal, or reap
    # @return [void]
    # @raise [Error] arming receipt identity or isolated group does not match
    def verify_armed(pid)
      receipt = await(10, pid)
      expected = [@ownership.token, @ownership.root, @ownership.identity, Ownership.identity_for(pid)]
      raise Error, 'Cleanup authority identity mismatch' unless receipt.values_at('token', 'root', 'identity', 'process') == expected

      group, = Command.new(timeout: 3).call('ps', '-o', 'pgid=', '-p', pid.to_s, timeout: 2)
      raise Error, 'Cleanup authority remained in payload process group' if group.to_i == Process.getpgrp
    end
  end

  # Requests cleanup, awaits its token-bound receipt, and reaps the authority child.
  class AuthorityCompletion
    # Retain ownership and the directly owned cleanup-authority PID.
    # @param ownership [Ownership] exclusive validated ownership scope
    # @param pid [Integer] process ID to observe, signal, or reap
    def initialize(ownership, pid)
      @ownership = ownership
      @pid = pid
    end

    # Request cleanup, await its success receipt, and reap the authority child.
    # @return [Hash]
    # @raise [Error] cleanup token or success flag differs or child cannot be reaped
    def finish
      @ownership.request_cleanup
      data = AuthorityReceipt.new(@ownership, 'cleanup.json').await(65)
      Deadline.new(3).poll('Cleanup authority did not exit after acknowledgement') { Process.waitpid(@pid, Process::WNOHANG) }
      raise Error, 'Owned cleanup failed; inspect private cleanup receipt' unless data['token'] == @ownership.token && data['clean'] == true

      data
    end
  end

  # Parent death closes the private command pipe. Let its bounded guardian drain
  # and reap its privileged observer before an outside authority freezes it.
  class GuardianDeparture
    # Retain ownership for owner departure and registered-process observations.
    # @param ownership [Ownership] exclusive validated ownership scope
    def initialize(ownership)
      @ownership = ownership
    end

    # If the owner has departed, await registered command identities becoming nonrunning.
    # @return [void]
    def settle
      return if Ownership.alive?(@ownership.read.fetch('owner'))

      limit = Deadline.new(2)
      until registered_nonrunning?
        return if SmokeConsumer.clock >= limit.expires_at

        sleep 0.05
      end
    end

    private

    # Compare every registered identity against one fresh census.
    # @return [Boolean]
    def registered_nonrunning?
      identities = @ownership.read.fetch('processes')
      census = ProcessCensus.observe
      identities.none? { |identity| census.process(identity.fetch('pid')).matches_live?(identity) }
    end
  end

  # Names only fixed library sources, never private paths, method names, or arguments.
  class CleanupFailureLocations
    # Fixed source basenames admitted to the private failure receipt.
    SOURCES = %w[command.rb cleanup_authority.rb ownership.rb].freeze

    # Retain the original exception without changing its backtrace or cause.
    # @param error [Exception] actual observed cleanup failure
    def initialize(error)
      @error = error
    end

    # Extract at most twenty source positions from the fixed cleanup library.
    # @return [Array<Hash>] allowlisted source basenames and native line numbers
    def to_a
      Array(@error.backtrace_locations).first(20).filter_map do |location|
        source = source_for(location.absolute_path)
        { 'source' => source, 'line' => location.lineno } if source
      end
    end

    private

    # Admit an absolute source only when it matches the fixed cleanup library.
    # @param path [String, nil] original native exception source path
    # @return [String, nil] admitted source basename, or no disclosure
    def source_for(path)
      SOURCES.find { |name| path == File.join(__dir__, name) }
    end
  end

  # Retains bounded failure fingerprints without exposing private exception messages.
  class CleanupFailure
    # Retain the fixed cleanup stage and the actual rescued exception.
    # @param stage [String] fixed stage assigned by the cleanup authority
    # @param error [Exception] original observed failure, including its cause chain
    def initialize(stage, error)
      @stage = stage
      @error = error
      @current = nil
    end

    # Fingerprint at most four distinct exceptions, explicitly disclosing truncation.
    # @return [Hash] stage and bounded class/message-digest observations
    def to_h
      causes = []
      locations = []
      queries = []
      seen = {}.compare_by_identity
      @current = @error
      while @current && causes.length < 4 && !seen.key?(@current)
        seen[@current] = true
        record(causes, locations, queries)
        @current = @current.cause
      end
      { 'version' => 1, 'stage' => @stage, 'causes' => causes, 'cause_locations' => locations,
        'cause_chain_truncated' => @current ? true : false, 'process_queries' => queries }
    end

    private

    # Append this actual cause's fingerprint, admitted positions, and typed query metrics.
    # @param causes [Array<Hash>] bounded exception fingerprints
    # @param locations [Array<Array<Hash>>] corresponding admitted native source positions
    # @param queries [Array<Hash>] bounded process-query diagnostics without observed output
    # @return [void]
    def record(causes, locations, queries)
      causes << { 'class' => @current.class.name.to_s.byteslice(0, 256),
                  'message_sha256' => Digest::SHA256.hexdigest(@current.message.to_s) }
      locations << CleanupFailureLocations.new(@current).to_a
      queries << @current.observation if @current.is_a?(ProcessQueryFailure)
    end
  end

  # Runs a detached cleanup watcher armed before consumer or Docker allocations.
  class CleanupAuthority
    # Fork the detached watcher and verify its armed identity before returning its PID.
    # @param ownership [Ownership] exclusive validated ownership scope
    # @return [Integer]
    def self.arm(ownership)
      pid = fork { detached_watch(ownership) }
      AuthorityReceipt.new(ownership, 'armed.json').verify_armed(pid)
      pid
    end

    # Create a detached session with null stdio and exit directly after watching or failure.
    # @param ownership [Ownership] exclusive validated ownership scope
    # @return [void]
    def self.detached_watch(ownership)
      Process.setsid
      $stdin.reopen(File::NULL)
      $stdout.reopen(File::NULL, 'w')
      $stderr.reopen(File::NULL, 'w')
      new(ownership).watch
      exit! 0 # rubocop:disable Rails/Exit -- detached authority must not run inherited exit handlers.
    rescue StandardError
      exit! 1 # rubocop:disable Rails/Exit -- explicit authority process boundary.
    end

    # Request and verify cleanup completion for the armed authority.
    # @param ownership [Ownership] exclusive validated ownership scope
    # @param pid [Integer] process ID to observe, signal, or reap
    # @return [Hash]
    def self.finish(ownership, pid)
      AuthorityCompletion.new(ownership, pid).finish
    end

    # Retain ownership before allocating a bounded cleanup command executor.
    # @param ownership [Ownership] exclusive validated ownership scope
    def initialize(ownership)
      @ownership = ownership
      @command = nil
      @stage = 'arming'
    end

    # Acknowledge arming, wait for cleanup, and retain sanitized stage and failure fingerprints.
    # @return [void]
    def watch
      acknowledge
      @stage = 'waiting'
      sleep 0.1 until cleanup_due?
      cleanup
    rescue StandardError => error
      @ownership.write_once('cleanup.json', 'token' => @ownership.token, 'clean' => false,
                                            'error' => error.class.name, 'failure' => CleanupFailure.new(@stage, error).to_h)
    end

    private

    # Write the exclusive token/root/inode and fresh process identity arming receipt.
    # @return [Integer]
    def acknowledge
      @ownership.write_once('armed.json', 'token' => @ownership.token, 'root' => @ownership.root,
                                          'identity' => @ownership.identity, 'process' => Ownership.identity_for(Process.pid))
    end

    # Check owner departure, elapsed deadline, or a validated token-bearing cleanup request.
    # @return [Boolean]
    # @raise [Error] cleanup request is linked or has the wrong token
    def cleanup_due?
      data = @ownership.read
      return true unless Ownership.alive?(data.fetch('owner'))
      return true if SmokeConsumer.clock >= data.fetch('deadline')

      request = File.join(@ownership.root, 'cleanup-request.json')
      return false unless File.exist?(request)
      raise Error, 'Invalid cleanup request' if File.symlink?(request) || JSON.parse(File.read(request))['token'] != @ownership.token

      true
    end

    # Stop registered processes, remove owned Docker/copy resources, and write verified cleanup results.
    # @return [void]
    def cleanup
      @command = Command.new(timeout: 60)
      process_result = remove_processes
      removed = remove_collections
      remove_destinations
      @stage = 'acknowledgement'
      @ownership.write_once('cleanup.json', 'token' => @ownership.token, 'clean' => true, 'removed' => removed,
                                            'consumer_roots_absent' => true, **process_result)
    end

    # Preserve each native process-cleanup step and identify its actual failure stage.
    # @return [Hash{String => Boolean}] positive registered-process observations
    def remove_processes
      @stage = 'guardian_settle'
      GuardianDeparture.new(@ownership).settle
      @stage = 'process_stop'
      stopped = ProcessTree.stop(@ownership.read.fetch('processes'))
      @stage = 'process_verify'
      verify_processes_nonrunning(stopped)
    end

    # Remove and verify absence of each owned container, volume, and network collection.
    # @return [Hash{String => Array<String>}]
    def remove_collections
      @stage = 'containers'
      containers = ContainerCollection.new(@ownership, @command).remove_all
      @stage = 'volumes'
      volumes = VolumeCollection.new(@ownership, @command).remove_all
      @stage = 'networks'
      networks = NetworkCollection.new(@ownership, @command).remove_all
      { 'container' => containers, 'volume' => volumes, 'network' => networks }
    end

    # Remove verified owned image tags and consumer directories.
    # @return [void]
    def remove_destinations
      @stage = 'images'
      data = @ownership.read
      data.fetch('projects').each { |project| OwnedImage.new(@ownership, @command, project).remove }
      @stage = 'consumer_roots'
      OwnedConsumerPath.remove_all(@ownership, data.fetch('consumers'))
    end

    # Require registered/stopped identities to be nonrunning and separately record positive absence.
    # @param stopped [Array<Hash>] identities frozen/killed by process cleanup
    # @return [Hash{String => Boolean}]
    # @raise [Error] a registered/stopped identity is still running
    def verify_processes_nonrunning(stopped)
      identities = (@ownership.read.fetch('processes') + stopped).uniq { |row| row.fetch('pid') }
      census = ProcessCensus.observe
      proofs = identities.map { |identity| ProcessTerminationProof.new(census, identity) }
      raise Error, 'Registered child remains' if proofs.any?(&:live?)

      { 'registered_processes_nonrunning' => true, 'registered_processes_absent' => proofs.all?(&:absent?) }
    end
  end
end
