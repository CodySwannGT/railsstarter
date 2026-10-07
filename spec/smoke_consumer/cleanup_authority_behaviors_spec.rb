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
        let(:object) do
          common = { 'Id' => 'fixture-resource-id', 'Name' => name }
          kind == 'container' ? common.merge('Config' => { 'Labels' => labels }) : common.merge('Labels' => labels)
        end
        let(:collection) { collection_type.new(ownership, command) }
        let(:list_arguments) { ['docker', *collection_type::LIST, '--filter', "label=#{SmokeConsumer::LABEL}=#{ownership.token}"] }
        let(:remove_arguments) { ['docker', kind, *collection_type::REMOVE, 'fixture-resource-id'] }

        before do
          ownership.register_resource(kind, 'fixture-resource-id', name, project)
          allow(command).to receive(:call).with(*list_arguments, timeout: 10).and_return(["fixture-resource-id\n", nil], ['', nil])
          allow(command).to receive(:call).with('docker', kind, 'inspect', 'fixture-resource-id', timeout: 10) { [JSON.generate([object]), nil] }
          allow(command).to receive(:call).with(*remove_arguments, timeout: 10).and_return(['', nil])
        end

        it 'removes the registered identity and requires a fresh empty inventory' do
          expect(collection.remove_all).to eq(['fixture-resource-id'])
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

            ["fixture-resource-id\n", nil]
          end
          expect { collection.remove_all }.to raise_error(SmokeConsumer::Error, 'daemon unavailable')
        end

        it 'rejects resources that remain after a successful remove response' do
          allow(command).to receive(:call).with(*list_arguments, timeout: 10).and_return(["fixture-resource-id\n", nil])
          expect { collection.remove_all }.to raise_error(SmokeConsumer::Error, "Owned #{kind} remains")
        end
      end
    end
  end

  context 'with an image protocol fixture' do
    let(:tag) { "#{project}-app:local" }
    let(:image) { SmokeConsumer::OwnedImage.new(ownership, command, project) }
    let(:object) { { 'Id' => 'fixture-image-id', 'Config' => { 'Labels' => labels } } }
    let(:success) { instance_double(Process::Status, success?: true) }
    let(:failure) { instance_double(Process::Status, success?: false) }

    before do
      ownership.register_resource('image', 'fixture-image-id', tag, project)
      allow(command).to receive(:capture).with('docker', 'image', 'inspect', tag, timeout: 10)
                                         .and_return([JSON.generate([object]), success], ['No such image', failure])
      allow(command).to receive(:call).with('docker', 'image', 'rm', tag, timeout: 10).and_return(['', nil])
    end

    it 'removes only the owned tag and independently observes its absence' do
      expect { image.remove }.not_to raise_error
      expect(command).to have_received(:call).with('docker', 'image', 'rm', tag, timeout: 10).once
      expect(command).to have_received(:capture).twice
    end

    it 'accepts explicit absence without issuing a remove command' do
      allow(command).to receive(:capture).and_return(['No such image', failure])
      expect { image.remove }.not_to raise_error
      expect(command).not_to have_received(:call)
    end

    it 'preserves an image when its registered immutable identity changes' do
      object['Id'] = 'substituted-image-id'
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

    it 'arms a genuine separate authority and reaps it after empty owned cleanup' do
      pid = described_class.arm(ownership)
      expect(Process.getpgid(pid)).to eq(pid)
      receipt = described_class.finish(ownership, pid)
      pid = nil
      expect(receipt.fetch('clean')).to be(true)
      expect(receipt.fetch('removed')).to eq('container' => [], 'volume' => [], 'network' => [])
    ensure
      if pid
        Process.kill('KILL', pid)
        Process.waitpid(pid)
      end
    end

    it 'acknowledges cleanup only after empty Docker inventories and actual directory removal' do
      Dir.mkdir(consumer_path, 0o700)
      allow(SmokeConsumer::Command).to receive(:new).with(timeout: 60).and_return(command)
      allow(command).to receive_messages(call: ['', nil], capture: ['No such image', instance_double(Process::Status, success?: false)])
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
