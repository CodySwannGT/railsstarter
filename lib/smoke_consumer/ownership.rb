# frozen_string_literal: true

module SmokeConsumer
  # Observation failures are errors. Only a complete successful census can report absence.
  class QueryStreams
    # Allocate output/error pipes, binary buffers, and active observer readers.
    def initialize
      @pairs = {}
      %i[output error].each { |role| @pairs[role] = PipeChannel.new }
      @buffers = {}
      @pairs.each_key { |role| @buffers[role] = +''.b }
      @readers = @pairs.transform_values(&:reader)
    end

    # Expose owned stdout/stderr endpoints and request descriptor/environment isolation.
    # @return [Hash]
    def child_options
      { out: @pairs.fetch(:output).writer, err: @pairs.fetch(:error).writer, close_others: true, unsetenv_others: true }
    end

    # Close the query writers in the observing parent.
    # @return [void]
    def parent_ready
      @pairs.each_value(&:close_writer)
    end

    # Drain both ps streams within the deadline and return their separate binary buffers.
    # @param limit [Deadline] shared monotonic operation deadline
    # @return [Array(String, String)]
    def collect(limit)
      until @readers.empty?
        limit.check('Process observer deadline exceeded')
        ready = IO.select(@readers.values, nil, nil, 0.05)&.first || []
        ready.each { |reader| read_ready(reader) }
      end
      @buffers.values_at(:output, :error)
    end

    # Close both output/error pipe channels.
    # @return [void]
    def close
      @pairs.each_value(&:close)
    end

    private

    # Drain a ready ps stream, reject output beyond 8 MiB, and retire it on EOF.
    # @param reader [IO] owned output read endpoint
    # @return [void]
    def read_ready(reader)
      role = @readers.key(reader)
      @buffers.fetch(role) << reader.read_nonblock(16_384)
      raise Error, 'Process observer output exceeded bound' if @buffers.values.sum(&:bytesize) > 8 * 1024 * 1024
    rescue EOFError
      @readers.delete(role)
      reader.close
    rescue IO::WaitReadable, Errno::EINTR
      nil
    end
  end

  # ps is a bounded, directly owned observer child; it never invokes the command guardian.
  class ProcessQuery
    attr_reader :pid

    # Allocate fresh query streams with no observer PID or exit status yet.
    def initialize
      @streams = QueryStreams.new
      @pid = nil
      @status = nil
    end

    # Isolate ps from managed groups: platforms may run it with a different effective UID.
    # Keep fresh C-locale observation, bounded collection/reaping, and successful clean output.
    # @return [String]
    def call
      environment = SmokeConsumer.environment.merge('LC_ALL' => 'C', 'LANG' => 'C')
      @pid = Process.spawn(environment, 'ps', '-eo', 'pid=,ppid=,pgid=,uid=,lstart=,stat=', pgroup: true, **@streams.child_options)
      @streams.parent_ready
      output, error = @streams.collect(Deadline.new(2))
      reap
      raise Error, 'Process observer failed or denied access' unless @status.success? && error.empty?

      output
    rescue Errno::ENOENT, Errno::EACCES => error
      raise Error, "Process observer unavailable: #{error.class}"
    ensure
      DirectChild.new(@pid).terminate if @pid && !@status
      @streams.close
    end

    private

    # Wait nonblockingly for the direct observer under a two-second deadline.
    # @return [void]
    def reap
      Deadline.new(2).poll('Process observer reap deadline exceeded') do
        result = Process.waitpid2(@pid, Process::WNOHANG)
        @status = result.last if result
      end
    end
  end

  # Represents positive absence from a fresh census, rather than an unknown process state.
  class AbsentProcess
    # Reject attempts to infer an identity from positive process absence.
    # @return [void]
    # @raise [Error] no process exists from which to derive an identity
    def identity
      raise Error, 'Process birth identity unavailable: positively absent'
    end

    # Report that a positively absent observation cannot match a live identity.
    # @param _identity [Hash] expected process identity, deliberately ignored by the absence sentinel
    # @return [Boolean]
    def matches_live?(_identity)
      false
    end

    # Accept positive absence as a nonrunning observation.
    # @param _identity [Hash] expected process identity
    # @return [Boolean]
    def nonrunning?(_identity)
      true
    end

    # Report positive absence in the observed census.
    # @return [Boolean]
    def absent?
      true
    end
  end

  # Parses and validates the fixed C-locale fields of one ps observation.
  class ProcessFields
    # Expected C-locale five-field process start-time format.
    BIRTH = /\A(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun) (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) [0-9]{1,2} [0-9]{2}:[0-9]{2}:[0-9]{2} [0-9]{4}\z/
    # Admitted ps state-field characters; indeterminate state is rejected separately.
    STATE = /\A[A-Za-z?][A-Za-z0-9+<>-]*\z/

    # Split one ps row and require its fixed ten-field observation layout.
    # @param line [String] one C-locale ps row
    # @raise [Error] ps row has the wrong field count
    def initialize(line)
      @fields = line.split
      raise Error, 'Malformed process observer row' unless @fields.size == 10
    end

    # Validate and parse PID, parent PID, process group, and UID fields.
    # @return [Array<Integer>]
    # @raise [Error] numeric ps fields are malformed
    def numbers
      values = @fields.take(4)
      raise Error, 'Malformed process observer row' unless values.all? { |field| field.match?(/\A[0-9]+\z/) }

      values.map(&:to_i)
    end

    # Validate and return the C-locale process start-time string.
    # @return [String]
    # @raise [Error] process start-time format is malformed
    def birth
      value = @fields[4..8].join(' ')
      raise Error, "Malformed process birth: #{value}" unless value.match?(BIRTH)

      value
    end

    # Validate and return the observed process state field.
    # @return [String]
    # @raise [Error] process state format is malformed
    def state
      value = @fields.last
      raise Error, "Malformed process state: #{value}" unless value.match?(STATE)

      value
    end
  end

  # Compares process birth, user, and group identity within one fresh observation.
  class ProcessObservation
    attr_reader :pid, :parent, :group, :uid

    # Parse validated PID/parent/group/UID, birth time, and process state fields.
    # @param line [String] one C-locale ps row
    def initialize(line)
      fields = ProcessFields.new(line)
      @pid, @parent, @group, @uid = fields.numbers
      @birth = fields.birth
      @state = fields.state
    end

    # Return PID/start-time identity only for an observed non-zombie process.
    # @return [Hash{String => Object}]
    # @raise [Error] state is indeterminate or zombie
    def identity
      require_observed_state
      raise Error, 'Process birth identity unavailable: zombie' if zombie?

      { 'pid' => pid, 'birth' => @birth }
    end

    # Extend birth identity with process group and UID for cleanup authority.
    # @return [Hash{String => Object}]
    def group_identity
      identity.merge('pgid' => group, 'uid' => uid)
    end

    # Match birth identity and reject changed UID/group or indeterminate state.
    # @param expected [Hash{String => Object}] previous observed birth/group identity
    # @return [Boolean]
    # @raise [Error] observed UID/group changed or state is indeterminate
    def matches_live?(expected)
      wanted = Ownership.process_identity(expected)
      return false if zombie? || identity != wanted.slice('pid', 'birth')
      raise Error, 'Owned process group or UID changed' unless wanted == group_identity.slice(*wanted.keys)

      true
    end

    # Keep indeterminate observations pending; otherwise require a nonmatching live identity.
    # @param expected [Hash{String => Object}] previous observed birth/group identity
    # @return [Boolean]
    def nonrunning?(expected)
      return false if @state.start_with?('?')

      !matches_live?(expected)
    end

    # Report that this row is observed rather than positively absent.
    # @return [Boolean]
    def absent?
      false
    end

    # Identify an owned-user child of the tracked parents, excluding already tracked PIDs.
    # @param parents [Array<Integer>] already tracked parent PIDs
    # @return [Boolean]
    def child_of?(parents)
      parents.include?(@parent) && parents.none?(@pid) && @uid == Process.uid
    end

    # Select a running observation whose PID is not already tracked.
    # @param parents [Array<Integer>] already tracked parent PIDs
    # @return [Boolean]
    def unseen?(parents)
      running? && parents.none?(@pid)
    end

    # Reject indeterminate state and distinguish running/non-zombie observations.
    # @return [Boolean]
    def running?
      require_observed_state
      !zombie?
    end

    private

    # Reject the indeterminate question-mark process state.
    # @return [void]
    def require_observed_state
      raise Error, 'Process state is indeterminate; nonrunning conclusion refused' if @state.start_with?('?')
    end

    # Identify a zombie state by its Z prefix.
    # @return [Boolean]
    def zombie?
      @state.start_with?('Z')
    end
  end

  # Provides validated process observations and ownership-aware descendant/group queries.
  class ProcessCensus
    # Build a fresh validated census excluding the direct ps observer.
    # @return [ProcessCensus]
    def self.observe
      query = ProcessQuery.new
      new(query.call, observer_pid: query.pid)
    end

    # Parse nonblank rows, require unique PIDs and caller presence, then omit the observer PID.
    # @param output [String] actual command or process-observer output
    # @param observer_pid [Integer] direct ps observer PID omitted from the census
    # @raise [Error] census has duplicate PIDs or omits the caller
    def initialize(output, observer_pid: 0)
      observations = output.lines.reject { |line| line.strip.empty? }.map { |line| ProcessObservation.new(line) }
      @rows = {}
      observations.each { |observation| @rows[observation.pid] = observation }
      raise Error, 'Incomplete or duplicate process observer census' unless @rows.size == observations.size && @rows.key?(Process.pid)

      @rows.delete(observer_pid)
    end

    # Return the observed PID row or a positive-absence sentinel.
    # @param pid [Integer] process ID to observe, signal, or reap
    # @return [ProcessObservation, AbsentProcess]
    def process(pid)
      @rows.fetch(pid) { AbsentProcess.new }
    end

    # Select children of the supplied parent PIDs owned by the current UID.
    # @param parents [Array<Integer>] already tracked parent PIDs
    # @return [Array<ProcessObservation>]
    def children(parents)
      @rows.values.select { |row| row.child_of?(parents) }
    end

    # Require the live owned anchor and select its running same-UID process group.
    # @param identity [Hash{String => Object}] expected observed PID/birth identity and optional group/UID fields
    # @return [Array<ProcessObservation>]
    # @raise [Error] anchor is absent, group is shared, or a member has foreign UID
    def group_members(identity)
      group = identity.fetch('pgid')
      raise Error, 'Caller process group refused' if group == Process.getpgrp && group != Process.pid
      raise Error, 'Command group anchor changed' unless process(group).matches_live?(identity)

      members = @rows.values.select { |row| row.group == group }.select(&:running?)
      raise Error, 'Foreign UID in command group' unless members.all? { |row| row.uid == identity.fetch('uid') }

      members
    end
  end

  # Private, inode-bound manifest shared with this invocation's cleanup authority.
  class Ownership
    attr_reader :root, :token, :identity

    # Validate the token, resolve the root, create a private MAC key, and retain device/inode identity.
    # @param root [String] consumer or ownership root path
    # @param token [String] 32-character hexadecimal scope token
    # @raise [Error] token is malformed
    def initialize(root, token)
      raise Error, 'Malformed ownership token' unless token.match?(/\A[a-f0-9]{32}\z/)

      @root = File.realpath(root)
      @token = token
      @key = SecureRandom.random_bytes(32)
      stat = File.stat(@root)
      @identity = [stat.dev, stat.ino]
    end

    # Create an exclusive private token root and signed owner/deadline/resource manifest.
    # @param base [String] existing private allocation directory
    # @param timeout [Numeric] cleanup deadline offset in seconds
    # @return [Ownership]
    def self.create(base, timeout:)
      validate_directory(base)
      token = SecureRandom.hex(16)
      root = File.join(base, "consumer-smoke-#{token}")
      Dir.mkdir(root, 0o700)
      instance = new(root, token)
      data = { 'token' => token, 'root' => root, 'identity' => instance.identity,
               'owner' => identity_for(Process.pid), 'deadline' => SmokeConsumer.clock + timeout,
               'projects' => [], 'consumers' => [], 'processes' => [], 'resources' => [] }
      data['header_mac'] = instance.sign(data.values_at('token', 'root', 'identity', 'owner', 'deadline'))
      instance.store(data)
      instance
    end

    # Reject symlinked ancestors and require a current-user private directory.
    # @param path [String] owned filesystem path
    # @return [void]
    # @raise [Error] directory is linked, foreign, or not private
    def self.validate_directory(path)
      absolute = File.expand_path(path)
      current = Pathname.new(absolute)
      current.ascend do |part|
        raise Error, 'Symlinked control/destination ancestor refused' if File.symlink?(part)
      end
      stat = File.stat(absolute)
      raise Error, 'Control base must be an existing owned private directory' unless File.directory?(absolute) && stat.uid == Process.uid && stat.mode.nobits?(0o077)
    end

    # Read a fresh process birth identity for the specified PID.
    # @param pid [Integer] process ID to observe, signal, or reap
    # @return [Hash{String => Object}]
    def self.identity_for(pid)
      ProcessCensus.observe.process(pid).identity
    end

    # Compare an expected identity with a fresh process observation.
    # @param identity [Hash{String => Object}] expected observed PID/birth identity and optional group/UID fields
    # @return [Boolean]
    def self.alive?(identity)
      ProcessCensus.observe.process(identity.fetch('pid')).matches_live?(identity)
    end

    # Select the PID, birth, group, and UID identity fields from a manifest row.
    # @param row [Hash{String => Object}] signed manifest process row
    # @return [Hash{String => Object}]
    def self.process_identity(row)
      row.slice('pid', 'birth', 'pgid', 'uid')
    end

    # Require unchanged realpath, device/inode, owner UID, and private root permissions.
    # @return [void]
    # @raise [Error] root path, inode, owner, or permissions changed
    def validate
      stat = File.stat(root)
      raise Error, 'Control root identity changed' if File.symlink?(root) || File.realpath(root) != root || identity != [stat.dev, stat.ino]
      raise Error, 'Control root permissions changed' unless stat.mode.nobits?(0o077) && stat.uid == Process.uid
    end

    # Read a bounded nonsymlink manifest and verify its root and signatures.
    # @return [Hash{String => Object}]
    # @raise [Error] manifest is linked, oversized, malformed, or unauthenticated
    def read
      validate
      file = File.join(root, 'manifest.json')
      raise Error, 'Symlinked or oversized manifest refused' if File.symlink?(file) || File.size(file) > 131_072

      manifest = JSON.parse(File.read(file))
      validate_manifest(manifest)

      manifest
    rescue JSON::ParserError
      raise Error, 'Malformed ownership manifest'
    end

    # Check root/header MAC, signed process rows, and token-bound project names.
    # @param manifest [Hash] validated ownership manifest
    # @return [void]
    # @raise [Error] manifest identity, MAC, process signatures, or project names differ
    def validate_manifest(manifest)
      raise Error, 'Malformed ownership manifest' unless manifest.values_at('token', 'root', 'identity') == [token, root, identity]
      raise Error, 'Ownership header changed' unless manifest['header_mac'] == sign(manifest.values_at('token', 'root', 'identity', 'owner', 'deadline'))
      raise Error, 'Process ownership changed' unless manifest.fetch('processes').all? { |row| row['mac'] == sign(self.class.process_identity(row)) }
      raise Error, 'Foreign project in manifest' unless manifest.fetch('projects').all? { |project| project.match?(/\Asmoke-#{token}-[a-z][a-z0-9-]{2,39}\z/) }
    end

    # Exclusively write and fsync a private temporary manifest before atomic replacement.
    # @param data [Hash] manifest, Docker observation, or committed input data used by this operation
    # @return [void]
    def store(data)
      validate
      file = File.join(root, 'manifest.json')
      raise Error, 'Symlinked manifest refused' if File.symlink?(file)

      temporary = File.join(root, "manifest-#{Process.pid}-#{SecureRandom.hex(4)}.json")
      File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |io|
        io.write(JSON.generate(data))
        io.flush
        io.fsync
      end
      File.rename(temporary, file)
    end

    # Freshly observe and sign a process identity before adding it to the manifest.
    # @param pid [Integer] process ID to observe, signal, or reap
    # @return [void]
    def register_process(pid)
      row = self.class.identity_for(pid)
      row['mac'] = sign(row)
      update { |data| data.fetch('processes') << row }
    end

    # Require a live own-session anchor and sign its group identity in the manifest.
    # @param identity [Hash{String => Object}] expected observed PID/birth identity and optional group/UID fields
    # @return [void]
    # @raise [Error] group lacks a live current-user isolated anchor
    def register_group(identity)
      group = identity.fetch('pgid')
      raise Error, 'Command group is not independently owned' unless identity.fetch('pid') == group && identity.fetch('uid') == Process.uid
      raise Error, 'Caller process group refused' if group == Process.getpgrp
      raise Error, 'Command group identity changed' unless self.class.alive?(identity)

      row = identity.merge('mac' => sign(identity))
      update { |data| data.fetch('processes') << row }
    end

    # Compute the manifest HMAC using this ownership instance's private key.
    # @param data [Hash, Array] manifest header fields or process identity to authenticate
    # @return [String]
    def sign(data)
      OpenSSL::HMAC.hexdigest('SHA256', @key, JSON.generate(data))
    end

    # Record kind, immutable ID, name, and project only under a registered project.
    # @param kind [String] owned Docker resource kind
    # @param id [String] actual immutable Docker resource identifier
    # @param name [String] name used by this operation
    # @param project [String] registered token-bound Compose project
    # @return [void]
    # @raise [Error] project is not registered
    def register_resource(kind, id, name, project)
      raise Error, 'Resource outside registered project' unless read.fetch('projects').include?(project)

      update { |data| data.fetch('resources') << { 'kind' => kind, 'id' => id, 'name' => name, 'project' => project } }
    end

    # Register a safe absent consumer destination and its token-bound Compose project.
    # @param name [String] name used by this operation
    # @return [Array(String, String)]
    # @raise [Error] name is unsafe or destination exists
    def register_consumer(name)
      raise Error, 'Unsafe consumer name' unless name.match?(/\A[a-z][a-z0-9_]{2,39}\z/)

      path = File.join(root, name)
      raise Error, 'Preexisting consumer refused' if File.exist?(path) || File.symlink?(path)

      project = "smoke-#{token}-#{name.tr('_', '-')}"
      update do |data|
        data.fetch('consumers') << path
        data.fetch('projects') << project
      end
      [path, project]
    end

    # Exclusively write the token-bearing cleanup request.
    # @return [void]
    def request_cleanup
      write_once('cleanup-request.json', { 'token' => token })
    end

    # Publish complete private JSON atomically without replacing an existing receipt.
    # An exclusive hard link keeps polling readers from observing a partial write.
    # @param name [String] name used by this operation
    # @param data [Hash] manifest, Docker observation, or committed input data used by this operation
    # @return [Integer]
    # @raise [Error] receipt name is unsafe or manifest/root validation fails
    def write_once(name, data)
      validate
      raise Error, 'Unsafe control filename' unless name.match?(/\A[a-z][a-z0-9-]*\.json\z/)

      ControlPublication.new(self, name, data).write
    end

    private

    # Lock the manifest, read/verify it, yield mutations, and atomically store the result.
    # @yield [manifest] verified mutable manifest
    # @yieldparam manifest [Hash] manifest updated under its exclusive file lock
    # @return [void]
    def update
      validate
      file = File.join(root, 'manifest.lock')
      raise Error, 'Symlinked ownership lock refused' if File.symlink?(file)

      File.open(file, File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        data = read
        yield data
        store(data)
      end
    end
  end

  # Owns one temporary inode until complete JSON is exclusively linked into place.
  class ControlPublication
    # @param ownership [Ownership] current private root validated by the caller
    # @param name [String] safe final control filename
    # @param data [Hash] JSON control contents
    def initialize(ownership, name, data)
      @ownership = ownership
      root = ownership.root
      @destination = File.join(root, name)
      @temporary = File.join(root, "control-#{SecureRandom.hex(16)}.json")
      @data = data
      @file = nil
      @identity = nil
    end

    # Close the writer and unlink only its own temporary inode on every outcome.
    # @return [Integer] original JSON write byte count
    def write
      File.open(@temporary, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
        @file = file
        @identity = file.stat
        publish
      end
    ensure
      remove_temporary if @identity
    end

    private

    # Flush complete bytes before atomic exclusive publication; never rename over a reader.
    # @return [Integer] original JSON write byte count
    def publish
      written = @file.write(JSON.generate(@data))
      @file.flush
      @file.fsync
      validate_temporary
      File.link(@temporary, @destination)
      written
    end

    # Reject a substituted file before linking or removing the owned temporary inode.
    # @return [void]
    # @raise [Error] inode, owner, or regular-file type changed
    def validate_temporary
      @ownership.validate
      stat = File.lstat(@temporary)
      expected = [@identity.dev, @identity.ino, Process.uid, 'file']
      raise Error, 'Control temporary identity changed' unless [stat.dev, stat.ino, stat.uid, stat.ftype] == expected
    end

    # Leave a colliding or substituted foreign path untouched.
    # @return [void]
    def remove_temporary
      validate_temporary
      File.unlink(@temporary)
    end
  end
end
