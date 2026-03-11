# frozen_string_literal: true

EXPECTED_TABLES = %w[
  alerts
  announcements
  api_clients_vendors
  api_orders
  assigned_broad_item_types
  assigned_narrow_item_types
  assigned_vendor_counties
  batches
  billing_methods
  broad_item_types
  census_providers
  checks
  client_column_mappings
  client_resolutions
  client_vendor_assignments
  clients
  comments
  contacts
  contract_billing_methods
  contract_items
  contracts
  counties
  districts
  dme_notifications
  duplicate_codes
  exceptions
  facilities
  fees
  gl_codes
  group1
  hcpcs
  hcpcs_modifiers
  hl7_files
  icd_codes
  invoice_checks
  invoice_exceptions
  invoice_exceptions_icd_codes
  invoices
  item_aliases
  item_markups
  item_options
  items
  jobs
  key_contacts
  line_items
  locations
  managers_orders
  narrow_item_types
  one_time_contract_items
  one_time_contracts
  orderable_items
  ordered_items
  orders
  organizations
  password_histories
  patient_aliases
  patient_statuses
  patients
  pickup_codes
  preauths
  prices
  processing_batches
  providers
  quality_improvements
  reason_codes
  rental_periods
  report_requests
  resolutions
  roles
  states
  statuses
  teams
  tenants
  user_announcements
  users
  users_roles
  vendor_afterhours_notification_logs
  vendor_afterhours_notifications
  vendor_column_mappings
  vendor_notifications
  vendor_recruitments
  vendors
].freeze

namespace :db do
  desc 'Verify that all expected legacy tables exist and no migrations are pending'
  task verify_schema: :environment do
    rails_internals = %w[schema_migrations ar_internal_metadata]
    solid_pattern = /\Asolid_(queue|cache|cable)_/

    actual_tables = ActiveRecord::Base.connection.tables
    filtered_tables = actual_tables.reject { |t| rails_internals.include?(t) || t.match?(solid_pattern) }

    pending_count = begin
      ActiveRecord::Migration.check_all_pending!
      0
    rescue ActiveRecord::PendingMigrationError => error
      error.message.scan(/\d{14}/).length
    end

    missing = EXPECTED_TABLES - filtered_tables
    extra = filtered_tables - EXPECTED_TABLES
    status = missing.empty? && extra.empty? && pending_count.zero? ? 'pass' : 'fail'

    result = {
      status: status,
      expected_count: EXPECTED_TABLES.length,
      actual_count: filtered_tables.length,
      missing: missing,
      extra: extra,
      pending_migrations: pending_count
    }

    puts result.to_json
  end
end
