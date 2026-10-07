# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/smoke_consumer'

RSpec.describe SmokeConsumer::DockerCollection do
  def docker_fixture(kind)
    identifiers = ['a' * 64, 'b' * 64]
    projects = %w[owned_one owned_two]
    objects = projects.zip(identifiers).map { |project, identifier| docker_object(kind, project, identifier) }
    state = { remaining: identifiers.dup, removed: [], objects: objects, inspection: nil }
    owner = instance_double(SmokeConsumer::Ownership, token: 'owned-token', read: { 'projects' => projects, 'resources' => [] })
    command = instance_double(SmokeConsumer::Command)
    allow(command).to receive(:call) { |*arguments, **_options| docker_reply(state, arguments) }
    type = kind == 'container' ? SmokeConsumer::ContainerCollection : SmokeConsumer::NetworkCollection
    state.merge!(collection: type.new(owner, command), owner: owner, command: command, identifiers: identifiers)
  end

  def docker_object(kind, project, identifier)
    labels = { SmokeConsumer::LABEL => 'owned-token', 'com.docker.compose.project' => project }
    return { 'Id' => identifier, 'Name' => "#{project}_default", 'Labels' => labels } if kind == 'network'

    { 'Id' => identifier, 'Name' => "/#{project}-worker-1", 'Config' => { 'Labels' => labels } }
  end

  def docker_reply(state, arguments)
    case arguments[2]
    when 'inspect'
      objects = state[:inspection] || arguments.drop(3).map { |identifier| state[:objects].find { |object| object['Id'] == identifier } }
      [JSON.generate(objects), nil]
    when 'rm'
      identifiers = arguments.drop(3).reject { |argument| argument.start_with?('--') }
      state[:removed].concat(identifiers)
      state[:remaining] -= identifiers
      ['', nil]
    else
      [state[:remaining].join("\n"), nil]
    end
  end

  malformed_responses = [[], {}, [nil]].freeze
  %w[container network].each do |kind|
    context "with immutable #{kind} identities" do
      it 'removes a complete owned set even when inspection returns it in another order' do
        fixture = docker_fixture(kind)
        fixture[:inspection] = fixture[:objects].reverse
        expect(fixture[:collection].remove_all).to eq(fixture[:identifiers])
        expect(fixture[:removed]).to eq(fixture[:identifiers])
      end

      it 'refuses a foreign sibling before deleting any object in the batch' do
        fixture = docker_fixture(kind)
        object = fixture[:objects].last
        labels = kind == 'container' ? object.fetch('Config').fetch('Labels') : object.fetch('Labels')
        labels[SmokeConsumer::LABEL] = 'foreign-token'
        expect { fixture[:collection].remove_all }.to raise_error(SmokeConsumer::Error, 'Docker ownership mismatch')
        expect(fixture[:removed]).to be_empty
      end

      it 'refuses partial inspection without deleting an uninspected identity' do
        fixture = docker_fixture(kind)
        fixture[:inspection] = [fixture[:objects].first]
        expect { fixture[:collection].remove_all }.to raise_error(SmokeConsumer::Error, /inspection.*inventory/)
        expect(fixture[:removed]).to be_empty
      end

      it 'refuses duplicate inspection instead of treating it as a complete set' do
        fixture = docker_fixture(kind)
        fixture[:inspection] = [fixture[:objects].first, fixture[:objects].first]
        expect { fixture[:collection].remove_all }.to raise_error(SmokeConsumer::Error, /inspection.*inventory/)
        expect(fixture[:removed]).to be_empty
      end

      it 'refuses an additional inspected object outside the owned inventory' do
        fixture = docker_fixture(kind)
        fixture[:inspection] = fixture[:objects] + [docker_object(kind, 'owned_one', 'c' * 64)]
        expect { fixture[:collection].remove_all }.to raise_error(SmokeConsumer::Error, /inspection.*inventory/)
        expect(fixture[:removed]).to be_empty
      end

      it 'refuses a Name-only inspection response rather than using it as immutable authority' do
        fixture = docker_fixture(kind)
        fixture[:objects].last.delete('Id')
        fixture[:inspection] = fixture[:objects]
        expect { fixture[:collection].remove_all }.to raise_error(SmokeConsumer::Error, /inspection.*inventory/)
        expect(fixture[:removed]).to be_empty
      end

      it 'refuses abbreviated inventory identities before inspection or deletion' do
        fixture = docker_fixture(kind)
        fixture[:remaining].map! { |identifier| identifier[0, 12] }
        expect { fixture[:collection].remove_all }.to raise_error(SmokeConsumer::Error, /immutable identities/)
        expect(fixture[:removed]).to be_empty
      end

      it 'refuses duplicate inventory identities before deleting any object' do
        fixture = docker_fixture(kind)
        fixture[:remaining].replace([fixture[:identifiers].first, fixture[:identifiers].first])
        expect { fixture[:collection].remove_all }.to raise_error(SmokeConsumer::Error, /immutable identities/)
        expect(fixture[:removed]).to be_empty
      end

      malformed_responses.each do |response|
        it "refuses an incomplete or malformed inspection response #{response.inspect}" do
          fixture = docker_fixture(kind)
          fixture[:inspection] = response
          expect { fixture[:collection].remove_all }.to raise_error(SmokeConsumer::Error, /inspection.*inventory/)
          expect(fixture[:removed]).to be_empty
        end
      end

      it 'refuses a changed recorded identity before deleting any sibling' do
        fixture = docker_fixture(kind)
        suffix = kind == 'container' ? '-worker-1' : '_default'
        record = { 'kind' => kind, 'name' => "owned_two#{suffix}", 'id' => 'c' * 64 }
        allow(fixture[:owner]).to receive(:read).and_return('projects' => %w[owned_one owned_two], 'resources' => [record])
        expect { fixture[:collection].remove_all }.to raise_error(SmokeConsumer::Error, 'Registered Docker identity changed')
        expect(fixture[:removed]).to be_empty
      end

      it 'does not acknowledge absence when a fresh owned resource appears after removal' do
        fixture = docker_fixture(kind)
        allow(fixture[:command]).to receive(:call) do |*arguments, **_options|
          reply = docker_reply(fixture, arguments)
          fixture[:remaining] << ('c' * 64) if arguments[2] == 'rm'
          reply
        end
        expect { fixture[:collection].remove_all }.to raise_error(SmokeConsumer::Error, "Owned #{kind} remains")
      end

      it 'propagates a partial native removal failure without claiming a clean result' do
        fixture = docker_fixture(kind)
        allow(fixture[:command]).to receive(:call) do |*arguments, **_options|
          if arguments[2] == 'rm'
            fixture[:remaining].delete(fixture[:identifiers].first)
            raise SmokeConsumer::Error, 'Native Docker removal failed'
          end
          docker_reply(fixture, arguments)
        end
        expect { fixture[:collection].remove_all }.to raise_error(SmokeConsumer::Error, 'Native Docker removal failed')
        expect(fixture[:remaining]).to include(fixture[:identifiers].last)
      end

      it 'keeps a genuinely empty inventory a no-op with a fresh absence read' do
        fixture = docker_fixture(kind)
        fixture[:remaining].clear
        expect(fixture[:collection].remove_all).to eq([])
        expect(fixture[:removed]).to be_empty
      end
    end
  end
end
