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
      expect(receipt).to eq('token' => ownership.token, 'clean' => false, 'error' => 'SmokeConsumer::Error')
      expect(File.exist?(File.join(ownership.root, 'armed.json'))).to be(true)
    end

    def with_cleanup_authority
      pid = described_class.arm(ownership)
      expect(Process.getpgid(pid)).to eq(pid)
      yield pid
    ensure
      SmokeConsumer::DirectChild.new(pid).terminate if pid
    end

    it 'arms a genuine separate authority and reaps it after empty owned cleanup' do
      with_cleanup_authority do |pid|
        receipt = described_class.finish(ownership, pid)
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
  end
end
