# frozen_string_literal: true

require 'active_record'
require 'active_record/tasks/database_tasks'
require 'rake'
require 'json'
require 'stringio'
require 'tmpdir'

RSpec.describe Rake::Task do
  let(:directory) { Dir.mktmpdir('configured-schema-') }
  let(:schema_path) { File.join(directory, 'renamed_schema.rb') }
  let(:db_config) { instance_double(ActiveRecord::DatabaseConfigurations::HashConfig, schema_format: :ruby) }
  let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter, tables: tables) }
  let(:tables) { %w[schema_migrations ar_internal_metadata] }
  let(:declarations) { '' }

  around do |example|
    previous = Rake.application
    Rake.application = Rake::Application.new
    described_class.define_task(:environment)
    load File.expand_path('../../../lib/tasks/db_verify.rake', __dir__)
    example.run
  ensure
    Rake.application = previous
    FileUtils.remove_entry(directory)
  end

  before do
    File.write(schema_path, "ActiveRecord::Schema[8.1].define(version: 0) do\n#{declarations}\nend\n")
    allow(ActiveRecord::Base).to receive_messages(connection: connection, connection_db_config: db_config)
    allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:schema_dump_path).with(db_config, :ruby).and_return(schema_path)
    allow(ActiveRecord::Migration).to receive(:check_all_pending!)
  end

  def verify
    output = StringIO.new
    previous = $stdout
    $stdout = output
    status = 0
    begin
      Rake::Task['db:verify_schema'].invoke
    rescue SystemExit => error
      status = error.status
    end
    [JSON.parse(output.string), status]
  ensure
    $stdout = previous
  end

  it 'passes an empty app using only Rails metadata and no domain tables' do
    expect(verify).to eq([{ 'status' => 'pass', 'expected_count' => 0, 'actual_count' => 0,
                            'missing' => [], 'extra' => [], 'pending_migrations' => false }, 0])
  end

  context 'with a renamed app table in its configured dump' do
    let(:declarations) { 'create_table "renamed_entries", force: :cascade do |t|; t.string "name"; end' }
    let(:tables) { %w[renamed_entries schema_migrations] }

    it 'derives expectations from that dump rather than the database inventory' do
      expect(verify.first).to include('status' => 'pass', 'expected_count' => 1, 'missing' => [])
    end

    it 'reports a missing declared table and exits nonzero' do
      allow(connection).to receive(:tables).and_return([])
      expect(verify).to match([hash_including('status' => 'fail', 'missing' => ['renamed_entries']), 1])
    end

    it 'reports an unexpected table and exits nonzero' do
      allow(connection).to receive(:tables).and_return(%w[renamed_entries unknown_entries])
      expect(verify).to match([hash_including('extra' => ['unknown_entries']), 1])
    end
  end

  it 'does not hide undeclared Solid tables from the primary database' do
    allow(connection).to receive(:tables).and_return(['solid_queue_jobs'])
    expect(verify).to match([hash_including('extra' => ['solid_queue_jobs']), 1])
  end

  it 'checks pending migrations without counting digits in error messages' do
    error = ActiveRecord::PendingMigrationError.new('Migrations pending. Run bin/rails db:migrate', pending_migrations: [])
    allow(ActiveRecord::Migration).to receive(:check_all_pending!).and_raise(error)
    expect(verify).to match([hash_including('pending_migrations' => true,
                                            'error' => %r{bin/rails db:migrate}), 1])
  end

  it 'reports the missing configured dump with a generation action' do
    FileUtils.rm(schema_path)
    expect(verify).to match([hash_including('error' => /renamed_schema.rb.*db:schema:dump/), 1])
  end

  it 'rejects a disabled dump instead of assuming db/schema.rb' do
    allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:schema_dump_path).and_return(nil)
    expect(verify).to match([hash_including('error' => /schema_dump.*db:schema:dump/), 1])
  end

  it 'reports an unreadable dump actionably' do
    allow(File).to receive(:read).with(schema_path).and_raise(Errno::EACCES)
    expect(verify).to match([hash_including('error' => /read.*renamed_schema.rb.*db:schema:dump/), 1])
  end

  it 'reports malformed generated Ruby' do
    File.write(schema_path, 'ActiveRecord::Schema[8.1].define(version: 0) do broken(')
    expect(verify).to match([hash_including('error' => /generated Ruby schema.*db:schema:dump/), 1])
  end

  it 'rejects arbitrary Ruby without evaluating it' do
    File.write(schema_path, 'raise "DO NOT EXECUTE"')
    expect(verify).to match([hash_including('error' => /generated Ruby schema.*db:schema:dump/), 1])
  end

  it 'rejects interpolated table names without evaluating them' do
    File.write(schema_path, %(ActiveRecord::Schema[8.1].define(version: 0) do; create_table "\#{raise}"; end))
    expect(verify).to match([hash_including('error' => /literal.*table.*db:schema:dump/), 1])
  end

  it 'rejects conditional declarations that cannot be statically determined' do
    File.write(schema_path, 'ActiveRecord::Schema[8.1].define(version: 0) do; if flag; create_table "maybe"; end; end')
    expect(verify).to match([hash_including('error' => /generated Ruby schema.*db:schema:dump/), 1])
  end

  it 'rejects a dynamic schema version without evaluating it' do
    File.write(schema_path, 'ActiveRecord::Schema[raise "DO NOT EXECUTE"].define(version: 0) do; end')
    expect(verify).to match([hash_including('error' => /generated Ruby schema.*db:schema:dump/), 1])
  end

  it 'reports unsupported SQL schema format before reading a Ruby dump' do
    allow(db_config).to receive(:schema_format).and_return(:sql)
    expect(verify).to match([hash_including('error' => /sql.*Ruby.*schema_format/), 1])
  end
end
