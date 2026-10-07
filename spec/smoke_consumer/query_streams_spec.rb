# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/smoke_consumer'

RSpec.describe SmokeConsumer::QueryStreams do
  context 'with query output channels' do
    let(:output) { SmokeConsumer::PipeChannel.new }
    let(:error) { SmokeConsumer::PipeChannel.new }
    let(:streams) { described_class.new }

    before do
      allow(SmokeConsumer::PipeChannel).to receive(:new).and_return(output, error)
      streams.child_options.fetch(:out).write('owned output bytes')
      streams.child_options.fetch(:err).write('owned diagnostic bytes')
      streams.parent_ready
    end

    after do
      streams.close
    end

    it 'retains partially read output and drains both channels after an interrupted native read' do
      attempts = 0
      allow(output.reader).to receive(:read_nonblock).and_wrap_original do |native, _size|
        attempts += 1
        raise Errno::EINTR if attempts == 2

        native.call(4)
      end

      expect(streams.collect(SmokeConsumer::Deadline.new(1))).to eq(['owned output bytes', 'owned diagnostic bytes'])
    end

    it 'keeps the original observation deadline when reads remain interrupted' do
      allow(output.reader).to receive(:read_nonblock).and_raise(Errno::EINTR)

      expect { streams.collect(SmokeConsumer::Deadline.new(0.05)) }
        .to raise_error(SmokeConsumer::Error, 'Process observer deadline exceeded')
    end

    it 'propagates read permission failures without reporting a complete census' do
      allow(output.reader).to receive(:read_nonblock).and_raise(Errno::EACCES)

      expect { streams.collect(SmokeConsumer::Deadline.new(1)) }.to raise_error(Errno::EACCES)
    end
  end

  context 'with command pipe endpoints' do
    let(:pipes) { SmokeConsumer::CommandPipes.new }

    after { pipes.close }

    it 'closes only parent-unneeded endpoints while retaining real output and status readers' do
      pipes.parent_ready

      expect([pipes.channel(:gate).reader, pipes.channel(:control).reader,
              pipes.channel(:output).writer, pipes.channel(:status).writer]).to all(be_closed)
      expect([pipes.channel(:gate).writer, pipes.channel(:control).writer,
              pipes.channel(:output).reader, pipes.channel(:status).reader]).to all(satisfy { |io| !io.closed? })
    end

    it 'closes only child-unneeded endpoints while retaining real output and status writers' do
      pipes.child_ready

      expect([pipes.channel(:gate).writer, pipes.channel(:control).writer,
              pipes.channel(:output).reader, pipes.channel(:status).reader]).to all(be_closed)
      expect([pipes.channel(:gate).reader, pipes.channel(:control).reader,
              pipes.channel(:output).writer, pipes.channel(:status).writer]).to all(satisfy { |io| !io.closed? })
    end

    it 'rejects a generic close action instead of closing both owned endpoints' do
      expect { pipes.send(:close_ends, output: :close) }
        .to raise_error(SmokeConsumer::Error, 'Unknown pipe close action')
      expect(pipes.channel(:output).reader).not_to be_closed
      expect(pipes.channel(:output).writer).not_to be_closed
    end
  end
end
