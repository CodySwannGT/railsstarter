# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/smoke_consumer'

RSpec.describe SmokeConsumer::QueryStreams do
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
