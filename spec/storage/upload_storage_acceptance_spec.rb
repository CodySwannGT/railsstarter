# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'json'
require 'rbconfig'
require_relative '../../lib/upload_storage'

RSpec.describe UploadStorage do
  class << self
    attr_accessor :storage_acceptance_report
  end

  let(:report) do
    self.class.storage_acceptance_report ||= begin
      root = File.expand_path('../..', __dir__)
      stdout, stderr, status = Open3.capture3('python3', File.join(root, 'test/runtime/active_storage/runner.py'),
                                              '--ruby', RbConfig.ruby, chdir: root)
      result = JSON.parse(stdout)
      raise "Storage acceptance failed: #{result['error']} #{result['cleanup_error']} #{stderr}" unless status.success?

      result
    end
  end

  %w[staging production].each do |environment|
    it "persists #{environment} bytes across independent roots and processes with the same attachment identity" do
      first = report.fetch('cases').fetch("#{environment}-first")
      second = report.fetch('cases').fetch("#{environment}-second")
      expect(first.fetch('pid')).not_to eq(second.fetch('pid'))
      expect(first.fetch('root')).not_to eq(second.fetch('root'))
      expect(first.fetch('key')).to eq(second.fetch('key'))
      expect(first.fetch('owner_id')).to eq(second.fetch('owner_id'))
      expect(second.fetch('download_sha256')).to eq(first.fetch('input_sha256'))
    end

    it "uses real #{environment} S3 requests and observes actual database rows" do
      first = report.fetch('cases').fetch("#{environment}-first")
      second = report.fetch('cases').fetch("#{environment}-second")
      expect(first.fetch('service_class')).to eq('ActiveStorage::Service::S3Service')
      expect(first.fetch('metadata_rows')).to include(hash_including('record_type' => 'StorageWitness', 'key' => first.fetch('key')))
      expect(first.fetch('api_requests').map { |request| request.fetch('operation') }).to eq(['put_object'])
      expect(second.fetch('api_requests').map { |request| request.fetch('operation') }).to eq(['get_object'])
      expect(report.fetch('independent_metadata_sha256')).to match(/\A[0-9a-f]{64}\z/)
    end
  end

  it 'falsifies the real detector with Disk and missing/corrupt stored objects, then restores actual uploaded bytes' do
    expect(report.fetch('disk_falsification')).to include('PERSISTENCE_DETECTOR: expected actual S3 adapter')
    cases = report.fetch('cases')
    expect(cases.fetch('disk-mutant-second').dig('error', 'class')).to eq('ActiveStorage::FileNotFoundError')
    expect(cases.fetch('missing-stored-object').dig('error', 'class')).to eq('ActiveStorage::FileNotFoundError')
    expect(cases.fetch('corrupt-stored-object').dig('error', 'message')).to eq('Stored object content mismatch')
    expect(cases.fetch('restored-object').fetch('success')).to be(true)
  end

  it 'fails visibly on missing/blank settings and actual after-commit AccessDenied without uploading to Disk' do
    denied = report.fetch('cases').fetch('access-denied')
    expect(denied).to include('success' => false, 'error' => hash_including('class' => 'Aws::S3::Errors::AccessDenied'))
    expect(denied.fetch('failure_metadata_rows')).not_to be_empty
    expect(denied.fetch('disk_files')).to be_empty
    failures = report.fetch('cases').select { |name, _| name.end_with?('-absent', '-blank') }
    expect(failures.size).to eq(8)
    expect(failures.values).to all(include('success' => false, 'error' => hash_including('class' => 'UploadStorage::ConfigurationError'), 'disk_files' => [], 's3_requests' => []))
  end

  %w[staging production].each do |environment|
    it "actually precompiles #{environment} without S3 settings/credentials or provider transport" do
      assets = report.fetch('cases').fetch("#{environment}-assets")
      expect(assets).to include('success' => true, 'selected_service' => 'upload_build_only', 's3_requests' => [], 'transports' => 0)
      expect(assets.fetch('asset_manifest_sha256')).to match(/\A[0-9a-f]{64}\z/)
    end
  end

  it 'keeps actual local/test Disk parsing without S3 settings' do
    services = %w[development test].map { |environment| report.fetch('cases').fetch("#{environment}-absent-s3").fetch('service_class') }
    expect(services).to all(eq('ActiveStorage::Service::DiskService'))
  end

  it 'preserves the locked engine metadata schema and real migration down/up semantics in fresh owned state' do
    migration = report.fetch('cases').fetch('migration-reversibility')
    expect(migration).to include('schema_matches_engine' => true, 'migration_down_clean' => true, 'migration_roundtrip_equal' => true)
    expect(migration.fetch('generated_schema_sha256')).to match(/\A[0-9a-f]{64}\z/)
    expect(migration.fetch('host_tables')).to eq(%w[active_storage_attachments active_storage_blobs active_storage_variant_records])
  end

  it 'positively cleans only owned resources and reaps every application process' do
    expect(report.fetch('all_children_reaped')).to be(true)
    expect(report.fetch('cleanup').size).to eq(2)
    expect(report.fetch('cleanup')).to all(include('container_absent' => true, 'volume_absent' => true, 'scratch_absent' => true))
    expect(report.fetch('cases').values).to all(include('identity_preflight' => true, 'transports' => 0))
  end
end
