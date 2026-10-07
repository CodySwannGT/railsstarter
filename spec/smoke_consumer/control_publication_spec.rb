# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require_relative '../../lib/smoke_consumer'

RSpec.describe SmokeConsumer::ControlPublication do
  let(:base) { Dir.mktmpdir('control-publication-', File.realpath(Dir.tmpdir)) }
  let(:ownership) { SmokeConsumer::Ownership.create(base, timeout: 20) }
  let(:destination) { File.join(ownership.root, 'cleanup-request.json') }

  after do
    FileUtils.remove_entry_secure(base)
  end

  def delayed_json
    Class.new do
      def to_json(*)
        sleep 0.3
        JSON.generate('complete')
      end
    end.new
  end

  it 'publishes complete JSON to a concurrent reader without exposing an empty final file' do
    path = destination
    reader = Thread.new do
      SmokeConsumer::Deadline.new(2).poll('Control publication did not appear') { File.exist?(path) }
      JSON.parse(File.read(path))
    rescue StandardError => error
      error.class.name
    end
    ownership.write_once('cleanup-request.json', 'state' => delayed_json)
    expect(reader.join(2)).to be(reader)
    expect(reader.value).to eq('state' => 'complete')
  ensure
    reader&.kill
    reader&.join(1)
  end

  it 'retains the write byte count and private regular final file with no temporary residue' do
    data = { 'token' => ownership.token }
    expect(ownership.write_once('cleanup-request.json', data)).to eq(JSON.generate(data).bytesize)
    expect(JSON.parse(File.read(destination))).to eq(data)
    expect(File.stat(destination).mode & 0o777).to eq(0o600)
    expect(File.stat(destination).nlink).to eq(1)
    expect(Dir.children(ownership.root).sort).to eq(%w[cleanup-request.json manifest.json])
  end

  it 'preserves an existing final file and leaves no owned temporary residue' do
    File.write(destination, 'sentinel', mode: 'wx', perm: 0o600)
    expect { ownership.request_cleanup }.to raise_error(Errno::EEXIST)
    expect(File.read(destination)).to eq('sentinel')
    expect(Dir.children(ownership.root).sort).to eq(%w[cleanup-request.json manifest.json])
  end

  it 'refuses a symlink destination without changing its target' do
    target = File.join(base, 'sentinel.json')
    File.write(target, 'foreign sentinel', mode: 'wx', perm: 0o600)
    File.symlink(target, destination)
    expect { ownership.request_cleanup }.to raise_error(Errno::EEXIST)
    expect(File.symlink?(destination)).to be(true)
    expect(File.read(target)).to eq('foreign sentinel')
    expect(Dir.children(ownership.root).sort).to eq(%w[cleanup-request.json manifest.json])
  end

  it 'leaves neither final JSON nor temporary residue when serialization fails' do
    expect { ownership.write_once('cleanup-request.json', 'bad' => Float::NAN) }.to raise_error(JSON::GeneratorError)
    expect(File.exist?(destination)).to be(false)
    expect(Dir.children(ownership.root)).to eq(['manifest.json'])
  end

  it 'preserves a colliding temporary file instead of deleting another writer inode' do
    instance = ownership
    nonce = 'a' * 32
    temporary = File.join(instance.root, "control-#{nonce}.json")
    File.write(temporary, 'temporary sentinel', mode: 'wx', perm: 0o600)
    allow(SecureRandom).to receive(:hex).with(16).and_return(nonce)

    expect { instance.request_cleanup }.to raise_error(Errno::EEXIST)
    expect(File.read(temporary)).to eq('temporary sentinel')
    expect(File.exist?(destination)).to be(false)
  end

  it 'removes only its temporary file after a flush-to-disk failure' do
    instance = ownership
    allow(File).to receive(:open).and_wrap_original do |original, path, *arguments, &block|
      original.call(path, *arguments) do |file|
        allow(file).to receive(:fsync).and_raise(Errno::EIO) if File.dirname(path) == instance.root
        block.call(file)
      end
    end

    expect { instance.request_cleanup }.to raise_error(Errno::EIO)
    expect(File.exist?(destination)).to be(false)
    expect(Dir.children(instance.root)).to eq(['manifest.json'])
  end

  it 'refuses an unsafe control name and a changed root before publishing' do
    expect { ownership.write_once('../escape.json', {}) }.to raise_error(SmokeConsumer::Error, 'Unsafe control filename')
    File.chmod(0o755, ownership.root)
    expect { ownership.request_cleanup }.to raise_error(SmokeConsumer::Error, 'Control root permissions changed')
    expect(File.exist?(destination)).to be(false)
  end
end
