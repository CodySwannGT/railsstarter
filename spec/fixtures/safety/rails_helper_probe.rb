# frozen_string_literal: true

# Real host boot and helper bytes, with driver tripwires installed before either.
# No rejection scenario can open a database socket, including the legacy control.
require 'bundler/setup'
require 'active_record'
require 'active_record/database_configurations'
require 'mysql2'
require 'json'
require 'tmpdir'
require 'fileutils'

root = File.expand_path('../../..', __dir__)
scenario, requested_environment, role = ARGV
ENV.keys.grep(/\A(?:AWS_|DATABASE_|PRIMARY_DB_|RAILS_|RACK_|SECRET_KEY_BASE)|_DATABASE_URL\z/).each { |key| ENV.delete(key) }
ENV.update('RAILS_ENV' => requested_environment, 'DATABASE_NAME' => 'owned62_synthetic',
           'PRIMARY_DB_HOST' => '127.0.0.1', 'DATABASE_PORT' => '1',
           'DATABASE_USER' => 'owned62_synthetic', 'AWS_EC2_METADATA_DISABLED' => 'true',
           'AWS_BOOTSTRAP_ENABLED' => 'false', 'SECRET_KEY_BASE_DUMMY' => '1')
ENV['RACK_ENV'] = 'development' if scenario == 'rack_mismatch'
ENV["#{role.upcase}_DATABASE_URL"] = 'mysql2://synthetic@127.0.0.1:1/owned62_nonisolated' if scenario == 'unsafe_url'

events = { driver: 0, schema_maintenance: 0, cleanup: 0 }
Mysql2::Client.define_singleton_method(:new) do |*|
  events[:driver] += 1
  raise 'owned62 synthetic driver tripwire reached'
end
ActiveRecord::Base.connection_handler.define_singleton_method(:clear_all_connections!) do |*|
  events[:cleanup] += 1
end
ActiveRecord::Migration.define_singleton_method(:maintain_test_schema!) do
  events[:schema_maintenance] += 1
  ActiveRecord::Base.connection_handler.clear_all_connections!
  Mysql2::Client.new
end

if scenario == 'postboot_invalid'
  original = ActiveRecord::Base.method(:configurations=)
  ActiveRecord::Base.define_singleton_method(:configurations=) do |config|
    altered = Marshal.load(Marshal.dump(config))
    altered.fetch('test').fetch(role)['database'] = 'owned62_nonisolated'
    original.call(altered)
  end
end

owned_tmp = Dir.mktmpdir('railsstarter-owned62-helper-')
result = { scenario: scenario, environment: requested_environment, role: role }
begin
  FileUtils.mkdir_p(File.join(owned_tmp, 'spec'))
  File.symlink(File.join(root, 'config'), File.join(owned_tmp, 'config'))
  # Coverage belongs to the parent suite. This child only measures load ordering.
  File.write(File.join(owned_tmp, 'spec/spec_helper.rb'), "# synthetic probe setup\n")
  source = scenario == 'legacy' ? File.join(__dir__, 'legacy_rails_helper.rb') : File.join(root, 'spec/rails_helper.rb')
  destination = File.join(owned_tmp, 'spec/rails_helper.rb')
  FileUtils.copy_file(source, destination)
  $:.unshift(File.join(owned_tmp, 'spec'))
  load destination
  result[:loaded] = true
rescue SystemExit => error
  result[:exit_status] = error.status
rescue StandardError => error
  result[:error_class] = error.class.name
  result[:tripwire_reached] = error.message == 'owned62 synthetic driver tripwire reached'
ensure
  result[:booted] = (defined?(Rails) && Rails.respond_to?(:application) && Rails.application&.initialized?) || false
  result[:events] = events
  FileUtils.remove_entry(owned_tmp)
  result[:cleanup_complete] = !File.exist?(owned_tmp)
  # rubocop:disable-next RSpec/Output -- Structured output is this standalone probe's contract.
  puts "OWNED62_RESULT=#{JSON.generate(result)}"
end
exit(result[:loaded] ? 0 : 1)
