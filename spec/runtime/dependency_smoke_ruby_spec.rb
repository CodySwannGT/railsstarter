# frozen_string_literal: true

require 'spec_helper'
require 'bundler'
require 'yaml'
require 'json'
require_relative '../fixtures/runtime/smoke'

RSpec.describe DependencySmoke do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:selected) { File.read(File.join(root, '.ruby-version')).strip }
  let(:release) { JSON.parse(File.read(File.join(root, 'spec/fixtures/runtime/acceptance.json'))).fetch('ruby_runtime') }

  it 'uses the declared patch in the actual interpreter and Bundler runtime metadata' do
    expect(RUBY_VERSION).to eq(selected)
    expect(selected).to eq(release.fetch('version'))
    expect(RUBY_PATCHLEVEL).to eq(release.fetch('patchlevel'))
    expect(Bundler.definition.ruby_version.versions).to eq([selected])
    expect(Bundler::LockfileParser.new(Bundler.read_file(File.join(root, 'Gemfile.lock'))).ruby_version)
      .to eq("ruby #{selected}p#{RUBY_PATCHLEVEL}")
  end

  it 'selects that same patch for mise and every web and worker image' do
    expect(File.read(File.join(root, '.mise.toml'))[/^ruby\s*=\s*"([^"]+)"$/, 1]).to eq(selected)
    %w[Dockerfile Dockerfile.local worker.Dockerfile worker.Dockerfile.local].each do |name|
      source = File.read(File.join(root, name))
      expect(source[/^ARG RUBY_VERSION=(.+)$/, 1]).to eq(selected), name
      expect(source.lines).to include("FROM docker.io/library/ruby:$RUBY_VERSION-slim-trixie@#{release.fetch('image_index')} AS base\n"), name
    end
  end

  it 'keeps the lint language target aligned with the interpreter minor' do
    config = YAML.safe_load_file(File.join(root, '.rubocop.yml'), permitted_classes: [Regexp, Symbol], aliases: true)
    expect(config.fetch('AllCops').fetch('TargetRubyVersion').to_s).to eq(selected.split('.').first(2).join('.'))
  end
end
