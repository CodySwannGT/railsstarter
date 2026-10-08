# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require_relative '../../lib/smoke_consumer'

RSpec.describe SmokeConsumer::CleanupAuthority do
  around do |example|
    example.run
  ensure
    FileUtils.remove_entry_secure(base)
  end

  let(:base) { Dir.mktmpdir('cleanup-authority', File.realpath(Dir.tmpdir)) }
  let(:ownership) { SmokeConsumer::Ownership.create(base, timeout: 20) }
  let(:consumer) { ownership.register_consumer('owned_consumer') }
  let(:consumer_path) { consumer.first }
  let(:project) { consumer.last }
  let(:command) { instance_double(SmokeConsumer::Command) }
  let(:labels) { { SmokeConsumer::LABEL => ownership.token, 'com.docker.compose.project' => project } }

  context 'with Docker protocol fixtures' do
    # These fixtures exercise refusal/acknowledgement logic; native Docker proof
    # comes from the separate public consumer journey.
    [SmokeConsumer::ContainerCollection, SmokeConsumer::VolumeCollection, SmokeConsumer::NetworkCollection].each do |collection_type|
      context "with #{collection_type::KIND} cleanup" do
        let(:kind) { collection_type::KIND }
        let(:name) do
          suffix = case kind
                   when 'container' then '-worker-1'
                   when 'volume' then '_mysql_data'
                   else '_default'
                   end
          "#{project}#{suffix}"
        end
        let(:identifier) { kind == 'volume' ? 'fixture-resource-id' : 'a' * 64 }
        let(:object) do
          common = { 'Id' => identifier, 'Name' => name }
          kind == 'container' ? common.merge('Config' => { 'Labels' => labels }) : common.merge('Labels' => labels)
        end
        let(:collection) { collection_type.new(ownership, command) }
        let(:list_arguments) { ['docker', *collection_type::LIST, '--filter', "label=#{SmokeConsumer::LABEL}=#{ownership.token}"] }
        let(:remove_arguments) { ['docker', kind, *collection_type::REMOVE, identifier] }

        before do
          ownership.register_resource(kind, identifier, name, project)
          allow(command).to receive(:call).with(*list_arguments, timeout: 10).and_return(["#{identifier}\n", nil], ['', nil])
          allow(command).to receive(:call).with('docker', kind, 'inspect', identifier, timeout: 10) { [JSON.generate([object]), nil] }
          allow(command).to receive(:call).with(*remove_arguments, timeout: 10).and_return(['', nil])
        end

        it 'removes the registered identity and requires a fresh empty inventory' do
          expect(collection.remove_all).to eq([identifier])
          expect(command).to have_received(:call).with(*remove_arguments, timeout: 10).once
          expect(command).to have_received(:call).with(*list_arguments, timeout: 10).twice
        end

        it 'refuses changed ownership before any removal' do
          labels[SmokeConsumer::LABEL] = 'foreign-token'
          expect { collection.remove_all }.to raise_error(SmokeConsumer::Error, 'Docker ownership mismatch')
          expect(command).not_to have_received(:call).with(*remove_arguments, timeout: 10)
        end

        it 'does not turn a failed final inventory into successful cleanup' do
          reads = 0
          allow(command).to receive(:call).with(*list_arguments, timeout: 10) do
            reads += 1
            raise SmokeConsumer::Error, 'daemon unavailable' if reads > 1

            ["#{identifier}\n", nil]
          end
          expect { collection.remove_all }.to raise_error(SmokeConsumer::Error, 'daemon unavailable')
        end

        it 'rejects resources that remain after a successful remove response' do
          allow(command).to receive(:call).with(*list_arguments, timeout: 10).and_return(["#{identifier}\n", nil])
          expect { collection.remove_all }.to raise_error(SmokeConsumer::Error, "Owned #{kind} remains")
        end
      end
    end
  end

  context 'with an image protocol fixture' do
    let(:tag) { "#{project}-app:local" }
    let(:image) { SmokeConsumer::OwnedImage.new(ownership, command, project) }
    let(:identifier) { "sha256:#{'a' * 64}" }
    let(:object) { { 'Id' => identifier, 'RepoTags' => [tag], 'RepoDigests' => [], 'Config' => { 'Labels' => labels } } }
    let(:success) { instance_double(Process::Status, success?: true) }
    let(:failure) { instance_double(Process::Status, success?: false, exitstatus: 1) }

    def image_absence(target)
      "[]\nError response from daemon: No such image: #{target}\n"
    end

    before do |example|
      ownership.register_resource('image', identifier, tag, project) unless example.metadata[:unregistered_image]
      inspections = 0
      allow(command).to receive(:capture).with('docker', 'image', 'inspect', tag, timeout: 10) do
        inspections += 1
        inspections == 1 ? [JSON.generate([object]), success] : [image_absence(tag), failure]
      end
      allow(command).to receive(:call).with('docker', 'image', 'rm', tag, timeout: 10).and_return(['', nil])
      allow(command).to receive(:call).with('docker', 'image', 'rm', '--no-prune', identifier, timeout: 10).and_return(['', nil])
      allow(command).to receive(:capture).with('docker', 'image', 'inspect', identifier, timeout: 10)
                                         .and_return([image_absence(identifier), failure])
    end

    it 'removes the immutable image without pruning parents and observes tag and ID absence' do
      expect { image.remove }.not_to raise_error
      expect(command).to have_received(:call).with('docker', 'image', 'rm', '--no-prune', identifier, timeout: 10).once
      expect(command).to have_received(:capture).with('docker', 'image', 'inspect', tag, timeout: 10).twice
      expect(command).to have_received(:capture).with('docker', 'image', 'inspect', identifier, timeout: 10).once
    end

    it 'accepts explicit absence without issuing a remove command' do
      allow(command).to receive(:capture).with('docker', 'image', 'inspect', tag, timeout: 10)
                                         .and_return([image_absence(tag), failure])
      expect { image.remove }.not_to raise_error
      expect(command).not_to have_received(:call)
      expect(command).to have_received(:capture).with('docker', 'image', 'inspect', identifier, timeout: 10).once
    end

    it 'refuses initial tag absence when the registered immutable image remains' do
      allow(command).to receive(:capture).with('docker', 'image', 'inspect', tag, timeout: 10)
                                         .and_return([image_absence(tag), failure])
      allow(command).to receive(:capture).with('docker', 'image', 'inspect', identifier, timeout: 10)
                                         .and_return([JSON.generate([object]), success])
      expect { image.remove }.to raise_error(SmokeConsumer::Error, 'App image ID remains or inventory failed')
      expect(command).not_to have_received(:call)
    end

    it 'refuses initial tag absence when registered image inventory is unknown' do
      allow(command).to receive(:capture).with('docker', 'image', 'inspect', tag, timeout: 10)
                                         .and_return([image_absence(tag), failure])
      allow(command).to receive(:capture).with('docker', 'image', 'inspect', identifier, timeout: 10)
                                         .and_return(['daemon unavailable', failure])
      expect { image.remove }.to raise_error(SmokeConsumer::Error, 'Image inventory unavailable')
      expect(command).not_to have_received(:call)
    end

    it 'preserves an image when its registered immutable identity changes' do
      object['Id'] = "sha256:#{'b' * 64}"
      allow(command).to receive(:capture).and_return([JSON.generate([object]), success])
      expect { image.remove }.to raise_error(SmokeConsumer::Error, 'Registered image identity changed')
      expect(command).not_to have_received(:call)
    end

    it 'preserves an image carrying another ownership token' do
      labels[SmokeConsumer::LABEL] = 'foreign-token'
      allow(command).to receive(:capture).and_return([JSON.generate([object]), success])
      expect { image.remove }.to raise_error(SmokeConsumer::Error, 'Unowned app image')
      expect(command).not_to have_received(:call)
    end

    it 'refuses a daemon error instead of declaring the image absent' do
      allow(command).to receive(:capture).and_return(['daemon unavailable', failure])
      expect { image.remove }.to raise_error(SmokeConsumer::Error, 'Image inventory unavailable')
      expect(command).not_to have_received(:call)
    end

    it 'requires disappearance after removing the owned tag' do
      allow(command).to receive(:capture).and_return([JSON.generate([object]), success])
      expect { image.remove }.to raise_error(SmokeConsumer::Error, 'App image tag remains or inventory failed')
    end

    it 'preserves an image with another tag alias' do
      object['RepoTags'] << 'foreign-app:local'
      expect { image.remove }.to raise_error(SmokeConsumer::Error, 'App image aliases are not exclusively owned')
      expect(command).not_to have_received(:call)
    end

    it 'preserves an image with a foreign digest alias' do
      object['RepoDigests'] << "foreign-app@sha256:#{'b' * 64}"
      expect { image.remove }.to raise_error(SmokeConsumer::Error, 'App image aliases are not exclusively owned')
      expect(command).not_to have_received(:call)
    end

    it 'refuses duplicate owned digest aliases' do
      digest = "#{tag.delete_suffix(':local')}@sha256:#{'b' * 64}"
      object['RepoDigests'] = [digest, digest]
      expect { image.remove }.to raise_error(SmokeConsumer::Error, 'App image aliases are not exclusively owned')
      expect(command).not_to have_received(:call)
    end

    it 'refuses malformed alias metadata instead of removing the image' do
      object['RepoDigests'] = nil
      expect { image.remove }.to raise_error(SmokeConsumer::Error, 'App image aliases are not exclusively owned')
      expect(command).not_to have_received(:call)
    end

    it 'requires the project to have been allocated before observing or removing its image' do
      unallocated = SmokeConsumer::OwnedImage.new(ownership, command, "smoke-#{ownership.token}-unallocated")
      allow(command).to receive(:capture).and_return([JSON.generate([object]), success], [image_absence(tag), failure])
      allow(command).to receive(:call).and_return(['', nil])
      expect { unallocated.remove }.to raise_error(SmokeConsumer::Error, 'Image outside registered project')
      expect(command).not_to have_received(:call)
      expect(command).not_to have_received(:capture)
    end

    it 'cleans a positively owned built image when build failure precedes ID registration', :unregistered_image do
      expect { image.remove }.not_to raise_error
      expect(command).to have_received(:call).with('docker', 'image', 'rm', '--no-prune', identifier, timeout: 10).once
      expect(ownership.read.fetch('resources')).to be_empty
    end

    it 'refuses a malformed native inspection without selecting its first object' do
      allow(command).to receive(:capture).with('docker', 'image', 'inspect', tag, timeout: 10)
                                         .and_return([JSON.generate([object, object]), success])
      expect { image.remove }.to raise_error(SmokeConsumer::Error, 'Malformed image inventory')
      expect(command).not_to have_received(:call)
    end

    it 'refuses a noncanonical image ID before any removal', :unregistered_image do
      object['Id'] = 'short-image-id'
      expect { image.remove }.to raise_error(SmokeConsumer::Error, 'Invalid immutable app image ID')
      expect(command).not_to have_received(:call)
    end

    it 'refuses duplicate registered identities instead of choosing the first one' do
      ownership.register_resource('image', identifier, tag, project)
      expect { image.remove }.to raise_error(SmokeConsumer::Error, 'Registered image identity changed')
      expect(command).not_to have_received(:call)
    end

    it 'refuses a present registration with a missing ID', :unregistered_image do
      ownership.register_resource('image', nil, tag, project)
      expect { image.remove }.to raise_error(SmokeConsumer::Error, 'Registered image identity changed')
      expect(command).not_to have_received(:call)
    end

    it 'does not accept an absence diagnostic naming another image' do
      allow(command).to receive(:capture).and_return([image_absence('foreign-app:local'), failure])
      expect { image.remove }.to raise_error(SmokeConsumer::Error, 'Image inventory unavailable')
      expect(command).not_to have_received(:call)
    end

    it 'does not accept absence mixed with another daemon failure' do
      allow(command).to receive(:capture).and_return(["#{image_absence(tag)}daemon unavailable\n", failure])
      expect { image.remove }.to raise_error(SmokeConsumer::Error, 'Image inventory unavailable')
      expect(command).not_to have_received(:call)
    end

    it 'requires a fresh ID-absence check even when the tag disappeared' do
      allow(command).to receive(:capture).with('docker', 'image', 'inspect', identifier, timeout: 10)
                                         .and_return([JSON.generate([object]), success])
      expect { image.remove }.to raise_error(SmokeConsumer::Error, 'App image ID remains or inventory failed')
    end

    it 'retains an actual removal deadline failure even if a later probe could find absence' do
      allow(command).to receive(:call).and_raise(SmokeConsumer::Error, 'Operation deadline exceeded')
      expect { image.remove }.to raise_error(SmokeConsumer::Error, 'Operation deadline exceeded')
      expect(command).to have_received(:capture).once
    end
  end

  context 'with actual disposable files' do
    # Refuse the second constructor while retaining a gated first native removal thread.
    # @param release [Queue] first worker's explicit release channel
    # @param state [Hash{Symbol => Thread, nil}] retained directly owned child
    # @return [void]
    def refuse_second_removal_thread(release, state)
      allow(Thread).to receive(:new).and_wrap_original do |native, &task|
        raise ThreadError, 'synthetic thread construction refusal' if state[:child]

        state[:child] = native.call do
          release.pop
          task.call
        end
        allow(state.fetch(:child)).to receive(:join).and_wrap_original do |join|
          release << true
          join.call
        end
        state.fetch(:child)
      end
    end

    it 'removes both independently owned trees and verifies repeated absence' do
      paths = [consumer_path, ownership.register_consumer('owned_second').first]
      paths.each do |path|
        Dir.mkdir(path, 0o700)
        File.write(File.join(path, 'owned.txt'), 'owned fixture')
      end
      SmokeConsumer::OwnedConsumerPath.remove_all(ownership, paths)
      expect(paths.none? { |path| File.exist?(path) }).to be(true)
      expect { SmokeConsumer::OwnedConsumerPath.remove_all(ownership, paths) }.not_to raise_error
    end

    it 'settles the owned tree removal while refusing a substituted symlink' do
      second = ownership.register_consumer('owned_second').first
      foreign = File.join(base, 'foreign_consumer')
      Dir.mkdir(foreign, 0o700)
      File.write(File.join(foreign, 'preserved.txt'), 'foreign witness')
      File.symlink(foreign, consumer_path)
      Dir.mkdir(second, 0o700)
      File.write(File.join(second, 'owned.txt'), 'owned fixture')
      expect { SmokeConsumer::OwnedConsumerPath.remove_all(ownership, [consumer_path, second]) }
        .to raise_error(SmokeConsumer::Error, 'Symlinked consumer path')
      expect(File.exist?(second)).to be(false)
      expect(File.read(File.join(foreign, 'preserved.txt'))).to eq('foreign witness')
    end

    it 'settles a real owned removal when starting the next removal thread fails' do
      second = ownership.register_consumer('owned_second').first
      Dir.mkdir(consumer_path, 0o700)
      File.write(File.join(consumer_path, 'owned.txt'), 'owned fixture')
      release = Queue.new
      state = { child: nil }
      refuse_second_removal_thread(release, state)
      expect { SmokeConsumer::OwnedConsumerPath.remove_all(ownership, [consumer_path, second]) }
        .to raise_error(ThreadError, 'synthetic thread construction refusal')
      expect(state.fetch(:child).alive?).to be(false)
      expect(File.exist?(consumer_path)).to be(false)
    ensure
      release << true if state&.fetch(:child)&.alive?
      state&.fetch(:child)&.join
    end

    it 'removes its direct child directory and accepts a repeated absence check' do
      Dir.mkdir(consumer_path, 0o700)
      File.write(File.join(consumer_path, 'owned.txt'), 'owned fixture')
      path = SmokeConsumer::OwnedConsumerPath.new(ownership, consumer_path)
      path.remove
      expect(File.exist?(consumer_path)).to be(false)
      expect { path.remove }.not_to raise_error
    end

    it 'preserves a sibling outside the ownership root' do
      foreign = File.join(File.dirname(ownership.root), 'foreign_consumer')
      Dir.mkdir(foreign, 0o700)
      expect { SmokeConsumer::OwnedConsumerPath.new(ownership, foreign).remove }.to raise_error(SmokeConsumer::Error, 'Unowned consumer path')
      expect(File.directory?(foreign)).to be(true)
    end

    it 'rejects a substituted consumer symlink and preserves its target' do
      foreign = File.join(File.dirname(ownership.root), 'foreign_consumer')
      Dir.mkdir(foreign, 0o700)
      File.symlink(foreign, consumer_path)
      expect { SmokeConsumer::OwnedConsumerPath.new(ownership, consumer_path).remove }.to raise_error(SmokeConsumer::Error, 'Symlinked consumer path')
      expect(File.directory?(foreign)).to be(true)
    end

    it 'rejects a symlinked acknowledgement even if its JSON reports success' do
      foreign = File.join(File.dirname(ownership.root), 'foreign.json')
      File.write(foreign, JSON.generate('clean' => true))
      File.symlink(foreign, File.join(ownership.root, 'cleanup.json'))
      expect { SmokeConsumer::AuthorityReceipt.new(ownership, 'cleanup.json').await(1) }.to raise_error(SmokeConsumer::Error, 'Symlinked authority acknowledgement')
    end

    it 'reports an authority exiting before acknowledgement' do
      pid = fork { exit! 0 }
      expect { SmokeConsumer::AuthorityReceipt.new(ownership, 'cleanup.json').await(2, pid) }
        .to raise_error(SmokeConsumer::Error, 'Cleanup authority exited before acknowledging')
    ensure
      begin
        Process.waitpid(pid) if pid
      rescue Errno::ECHILD
        nil
      end
    end
  end

  context 'with actual owned process cleanup' do
    def with_isolated_process
      read_pipe, write_pipe = IO.pipe
      pid = fork do
        read_pipe.close
        Process.setsid
        write_pipe.write('ready')
        write_pipe.close
        sleep 20
      end
      write_pipe.close
      expect(read_pipe.read).to eq('ready')
      yield pid
      Process.waitpid(pid)
      pid = nil
    ensure
      read_pipe&.close
      write_pipe&.close unless write_pipe&.closed?
      if pid
        Process.kill('KILL', pid)
        Process.waitpid(pid)
      end
    end

    it 'stops and reaps its own isolated session without touching the caller' do
      actual_pid = nil
      with_isolated_process do |pid|
        actual_pid = pid
        identity = SmokeConsumer::ProcessCensus.observe.process(pid).group_identity
        ownership.register_group(identity)
        stopped = SmokeConsumer::ProcessTree.stop(ownership.read.fetch('processes'))
        expect(stopped.map { |row| row.fetch('pid') }).to eq([pid])
      end
      expect(SmokeConsumer::Ownership.alive?(ownership.read.fetch('owner'))).to be(true)
      expect(SmokeConsumer::ProcessCensus.observe.process(actual_pid).absent?).to be(true)
    end

    it 'refuses caller signalling regardless of the supplied birth identity' do
      identity = SmokeConsumer::Ownership.identity_for(Process.pid)
      expect { SmokeConsumer::ProcessSignal.new(identity).stop }.to raise_error(SmokeConsumer::Error, 'Caller process refused')
    end

    def indeterminate_observations(identity, persistent)
      observations = 0
      pid = identity.fetch('pid')
      allow(SmokeConsumer::ProcessCensus).to receive(:observe).and_wrap_original do |native|
        census = native.call
        observations += 1
        if observations == 2 || (persistent && observations > 2)
          unknown = SmokeConsumer::ProcessObservation.new("#{pid} #{Process.pid} #{pid} #{Process.uid} #{identity.fetch('birth')} ?")
          allow(census).to receive(:process).with(pid).and_return(unknown)
        end
        census
      end
      -> { observations }
    end

    # State fixtures alter only observations after the actual owned KILL signal.
    [false, true].each do |persistent|
      it "#{persistent ? 'times out on a persistent' : 'waits through a transient'} indeterminate state after killing its owned process" do
        with_isolated_process do |pid|
          identity = SmokeConsumer::ProcessCensus.observe.process(pid).group_identity
          tree = SmokeConsumer::ProcessTree.new
          tree.freeze_roots([identity])
          observations = indeterminate_observations(identity, persistent)

          if persistent
            expect { tree.kill_frozen }.to raise_error(SmokeConsumer::Error, 'Owned process remains running')
          else
            expect(tree.kill_frozen).to eq([identity])
            expect(observations.call).to be >= 3
          end
        end
      end
    end

    it 'refuses a cleanup request with a foreign token and records failure' do
      ownership.write_once('cleanup-request.json', 'token' => 'foreign-token')
      described_class.new(ownership).watch
      receipt = JSON.parse(File.read(File.join(ownership.root, 'cleanup.json')))
      expect(receipt).to include('token' => ownership.token, 'clean' => false, 'error' => 'SmokeConsumer::Error')
      expect(receipt.fetch('failure')).to include(
        'stage' => 'waiting',
        'causes' => [{ 'class' => 'SmokeConsumer::Error',
                       'message_sha256' => Digest::SHA256.hexdigest('Invalid cleanup request') }]
      )
      expect(File.exist?(File.join(ownership.root, 'armed.json'))).to be(true)
    end

    # Execute a genuinely failing native child during the owned cleanup attempt.
    def fail_cleanup_with_native_child
      native_command = SmokeConsumer::Command.new(timeout: 60)
      collection = instance_double(SmokeConsumer::ContainerCollection)
      allow(collection).to receive(:remove_all) do
        native_command.call(RbConfig.ruby, '-e', "warn 'synthetic-private-output'; exit 17", timeout: 10)
      end
      allow(SmokeConsumer::ContainerCollection).to receive(:new).and_return(collection)
    end

    # Construct synthetic nested exceptions to check bounded private diagnostics.
    def private_cause_chain
      error = nil
      6.times do |index|
        raise error if error
      rescue StandardError
        begin
          raise SmokeConsumer::Error, "synthetic-private-message-#{index}"
        rescue StandardError => nested
          error = nested
        end
      else
        error = SmokeConsumer::Error.new("synthetic-private-message-#{index}")
      end
      error
    end

    # Produce native EBADF over the original synthetic failure.
    def native_descriptor_failure
      reader, writer = IO.pipe
      IO.for_fd(writer.fileno).close
      begin
        raise SmokeConsumer::Error, 'synthetic-private-original'
      rescue StandardError
        begin
          writer.close
        rescue Errno::EBADF => error
          error
        end
      end
    ensure
      reader&.close unless reader&.closed?
      writer&.close unless writer&.closed?
    end

    def with_cleanup_authority
      pid = described_class.arm(ownership)
      expect(Process.getpgid(pid)).to eq(pid)
      yield pid
    ensure
      SmokeConsumer::DirectChild.new(pid).terminate if pid
    end

    # Preserve finish's refusal while printing only its sanitized receipt evidence.
    def finish_with_failure_diagnostic(pid)
      described_class.finish(ownership, pid)
    rescue SmokeConsumer::Error
      warn cleanup_failure_diagnostic
      raise
    end

    # Select the cleanup failure record or an explicit unavailable indicator.
    def cleanup_failure_diagnostic
      receipt = JSON.parse(File.read(File.join(ownership.root, 'cleanup.json')))
      JSON.generate(receipt.slice('failure'))
    rescue SystemCallError, JSON::ParserError
      JSON.generate('failure_receipt_unavailable' => true)
    end

    it 'arms a genuine separate authority and reaps it after empty owned cleanup' do
      with_cleanup_authority do |pid|
        receipt = finish_with_failure_diagnostic(pid)
        expect(receipt.fetch('clean')).to be(true)
        expect(receipt.fetch('removed')).to eq('container' => [], 'volume' => [], 'network' => [])
      end
    end

    it 'preserves the cleanup failure after the genuine authority has been reaped' do
      allow(ownership).to receive(:request_cleanup) { ownership.write_once('cleanup-request.json', 'token' => 'foreign-token') }
      authority_pid = nil
      expect do
        with_cleanup_authority do |pid|
          authority_pid = pid
          described_class.finish(ownership, pid)
        end
      end.to raise_error(SmokeConsumer::Error, 'Owned cleanup failed; inspect private cleanup receipt')
      receipt = JSON.parse(File.read(File.join(ownership.root, 'cleanup.json')))
      expect(receipt).to include('token' => ownership.token, 'clean' => false, 'error' => 'SmokeConsumer::Error')
      expect { Process.waitpid(authority_pid, Process::WNOHANG) }.to raise_error(Errno::ECHILD)
    end

    it 'acknowledges cleanup only after empty Docker inventories and actual directory removal' do
      Dir.mkdir(consumer_path, 0o700)
      allow(SmokeConsumer::Command).to receive(:new).with(timeout: 60).and_return(command)
      allow(command).to receive(:call).and_return(['', nil])
      allow(command).to receive(:capture) do |_executable, _kind, _operation, target, **_options|
        ["[]\nError response from daemon: No such image: #{target}\n", instance_double(Process::Status, success?: false, exitstatus: 1)]
      end
      ownership.request_cleanup
      described_class.new(ownership).watch
      receipt = JSON.parse(File.read(File.join(ownership.root, 'cleanup.json')))
      expect(receipt.slice('clean', 'consumer_roots_absent', 'registered_processes_nonrunning', 'registered_processes_absent'))
        .to eq('clean' => true, 'consumer_roots_absent' => true, 'registered_processes_nonrunning' => true, 'registered_processes_absent' => true)
      expect(receipt.fetch('removed')).to eq('container' => [], 'volume' => [], 'network' => [])
      expect(File.exist?(consumer_path)).to be(false)
    end

    it 'retains the failed cleanup stage and native child failure without publishing command output' do
      fail_cleanup_with_native_child
      with_cleanup_authority do |pid|
        expect { described_class.finish(ownership, pid) }
          .to raise_error(SmokeConsumer::Error, 'Owned cleanup failed; inspect private cleanup receipt')
      end
      receipt = JSON.parse(File.read(File.join(ownership.root, 'cleanup.json')))
      expect(receipt.fetch('failure')).to include(
        'stage' => 'containers',
        'causes' => [{ 'class' => 'SmokeConsumer::Error',
                       'message_sha256' => Digest::SHA256.hexdigest('ruby failed (exit 17)') }]
      )
      expect(receipt.fetch('failure').fetch('cause_locations').first)
        .to include(a_hash_including('source' => 'command.rb', 'line' => be_positive))
      expect(JSON.generate(receipt)).not_to include('synthetic-private-output', RbConfig.ruby)
    end

    it 'bounds cleanup exception causes and fingerprints private messages without publishing them' do
      error = private_cause_chain
      failure = SmokeConsumer::CleanupFailure.new('containers', error).to_h
      expect([failure.fetch('causes').length, failure.fetch('cause_chain_truncated'), failure.fetch('cause_locations')])
        .to eq([4, true, [[], [], [], []]])
      expect(failure.fetch('causes').first).to eq(
        'class' => 'SmokeConsumer::Error', 'message_sha256' => Digest::SHA256.hexdigest('synthetic-private-message-5')
      )
      expect(JSON.generate(failure)).not_to include('synthetic-private-message')
      allow(error).to receive(:cause).and_return(error)
      cyclic_failure = SmokeConsumer::CleanupFailure.new('containers', error).to_h
      expect([cyclic_failure.fetch('causes').length, cyclic_failure.fetch('cause_chain_truncated'), cyclic_failure.fetch('cause_locations')])
        .to eq([1, true, [[]]])
    end

    it 'retains an original cleanup failure when native descriptor closure raises another exception' do
      failure = SmokeConsumer::CleanupFailure.new('containers', native_descriptor_failure).to_h
      expect(failure.fetch('causes').map { |cause| cause.fetch('class') }).to eq(['Errno::EBADF', 'SmokeConsumer::Error'])
      expect(failure.fetch('causes').last.fetch('message_sha256')).to eq(Digest::SHA256.hexdigest('synthetic-private-original'))
      expect(failure.fetch('cause_chain_truncated')).to be(false)
      expect(failure.fetch('cause_locations')).to eq([[], []])
      expect(JSON.generate(failure)).not_to include('synthetic-private-original')
    end

    it 'identifies destination cleanup when its native manifest becomes malformed after network cleanup' do
      allow(SmokeConsumer::Command).to receive(:new).with(timeout: 60).and_return(command)
      allow(command).to receive(:call).and_return(['', nil])
      allow(SmokeConsumer::NetworkCollection).to receive(:new).and_wrap_original do |original, *arguments|
        collection = original.call(*arguments)
        allow(collection).to receive(:remove_all).and_wrap_original do |remove|
          remove.call.tap { File.write(File.join(ownership.root, 'manifest.json'), '{') }
        end
        collection
      end
      ownership.request_cleanup
      described_class.new(ownership).watch
      receipt = JSON.parse(File.read(File.join(ownership.root, 'cleanup.json')))
      expect(receipt).to include('clean' => false, 'error' => 'SmokeConsumer::Error')
      expect(receipt.fetch('failure').fetch('stage')).to eq('images')
    end
  end
end
