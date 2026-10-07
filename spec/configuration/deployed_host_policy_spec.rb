# frozen_string_literal: true

require_relative '../../lib/deployed_host_policy'

RSpec.describe DeployedHostPolicy do
  it 'normalizes exact DNS and IP identities without wildcard or port grants' do
    expect(described_class.hosts('ALLOWED_HOSTS' => ' App.Example.test,127.0.0.1,[::1],app.example.test'))
      .to eq(['app.example.test', '127.0.0.1', '[::1]'])
  end

  it 'rejects absent, empty or malformed deployed identities with sanitized diagnostics' do
    [nil, '', ' ', 'a.test,', ',a.test', 'a.test,,b.test', '*.test', '.test', 'https://a.test',
     'a.test:443', 'a.test/path', 'a.test?x', 'a.test#x', 'user@a.test', '-a.test', 'a_.test',
     '999.1.1.1', '[bad]', '[::1/0]', '[fe80::1%lo0]', '::1', "a.test\nsecret"].each do |input|
      expect { described_class.hosts('ALLOWED_HOSTS' => input) }
        .to raise_error(ArgumentError, /ALLOWED_HOSTS/) { |error| expect(error.message).not_to include('secret') }
    end
  end

  it 'validates the optional HTTPS asset origin without broad sources' do
    expect(described_class.asset_origin('CLOUDFRONT_ENDPOINT' => 'https://assets.example.test/'))
      .to eq('https://assets.example.test')
    expect(described_class.asset_origin({})).to be_nil
    ['http://assets.test', 'https://*.test', 'https://user:secret@a.test', 'https://a.test/path',
     'https://a.test?x', 'https://a.test#x', '//a.test', 'https:', "https://a.test\n"].each do |input|
      expect { described_class.asset_origin('CLOUDFRONT_ENDPOINT' => input) }
        .to raise_error(ArgumentError, /CLOUDFRONT_ENDPOINT/)
    end
  end

  it 'requires genuine exclusive Rake compilation plus dummy context for the host omission' do
    require 'rake'
    allow(Rake.application).to receive(:top_level_tasks).and_return(['assets:precompile'])
    expect(described_class.asset_build?('SECRET_KEY_BASE_DUMMY' => '1')).to be(true)
    expect(described_class.asset_build?({})).to be(false)
    allow(Rake.application).to receive(:top_level_tasks).and_return(['assets:precompile', 'environment'])
    expect(described_class.asset_build?('SECRET_KEY_BASE_DUMMY' => '1')).to be(false)
    allow(Rake.application).to receive(:top_level_tasks).and_return([])
    expect(described_class.asset_build?('SECRET_KEY_BASE_DUMMY' => '1')).to be(false)
  end
end
