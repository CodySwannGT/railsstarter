# frozen_string_literal: true

require_relative '../schema_verification'

namespace :db do
  desc 'Verify configured primary schema tables and check for pending migrations'
  task verify_schema: :environment do
    begin
      db_config = ActiveRecord::Base.connection_db_config
      format = db_config.schema_format
      path = ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(db_config, format) if format == :ruby
      expected = GeneratedSchemaTables.new(path, format).tables
      result = SchemaVerification.new(expected, ActiveRecord::Base.connection.tables).result
      begin
        ActiveRecord::Migration.check_all_pending!
      rescue ActiveRecord::PendingMigrationError => error
        result.merge!(status: 'fail', pending_migrations: true, error: error.message)
      end
    rescue GeneratedSchemaTables::Error => error
      result = { status: 'fail', error: error.message }
    end

    puts result.to_json
    exit 1 unless result[:status] == 'pass'
  end
end
