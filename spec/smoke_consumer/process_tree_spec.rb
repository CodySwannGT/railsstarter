# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/smoke_consumer'

RSpec.describe SmokeConsumer::ProcessTree do
  let(:roots) do
    Array.new(124) do |index|
      pid = 1_000_000 + index
      { 'pid' => pid, 'pgid' => pid, 'uid' => Process.uid, 'birth' => 'Tue Oct 6 22:51:22 2026' }
    end
  end
  let(:absent) { SmokeConsumer::AbsentProcess.new }
  let(:census) { instance_double(SmokeConsumer::ProcessCensus, process: absent, children: []) }

  before do
    allow(Process).to receive(:kill) { raise 'Fixture refuses native signals' }
  end

  it 'cleans a large departed cohort without exhausting a bounded observer' do
    observations = 0
    allow(SmokeConsumer::ProcessCensus).to receive(:observe) do
      observations += 1
      raise SmokeConsumer::Error, 'Observer fixture budget exceeded' if observations > 4

      census
    end

    expect(described_class.stop(roots)).to eq([])
    expect(Process).not_to have_received(:kill)
  end

  it 'validates group authority even when a root is positively absent' do
    allow(SmokeConsumer::ProcessCensus).to receive(:observe).and_return(census)
    identity = roots.first.merge('pgid' => Process.getpgrp)

    expect { described_class.stop([identity]) }.to raise_error(SmokeConsumer::Error, 'Caller or unowned command group refused')
    expect(Process).not_to have_received(:kill)
  end

  it 'refuses a failed census rather than treating every root as absent' do
    allow(SmokeConsumer::ProcessCensus).to receive(:observe).and_raise(SmokeConsumer::Error, 'Process observer failed or denied access')

    expect { described_class.stop(roots) }.to raise_error(SmokeConsumer::Error, 'Process observer failed or denied access')
    expect(Process).not_to have_received(:kill)
  end

  it 'requires a fresh matching identity after an initially present observation' do
    present = instance_double(SmokeConsumer::ProcessObservation, absent?: false, matches_live?: true)
    initial = instance_double(SmokeConsumer::ProcessCensus, process: present)
    allow(SmokeConsumer::ProcessCensus).to receive(:observe).and_return(initial, census)

    expect(described_class.stop([roots.first])).to eq([])
    expect(Process).not_to have_received(:kill)
  end

  it 'does not classify an indeterminate observation as positive absence' do
    identity = roots.first
    unknown = SmokeConsumer::ProcessObservation.new("#{identity.fetch('pid')} 1 #{identity.fetch('pgid')} #{Process.uid} #{identity.fetch('birth')} ?")
    observation = instance_double(SmokeConsumer::ProcessCensus, process: unknown)
    allow(SmokeConsumer::ProcessCensus).to receive(:observe).and_return(observation)

    expect { described_class.stop([identity]) }.to raise_error(SmokeConsumer::Error, 'Process state is indeterminate; nonrunning conclusion refused')
    expect(Process).not_to have_received(:kill)
  end
end
