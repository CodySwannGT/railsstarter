# frozen_string_literal: true

# Dedicated aggregate security quota storage in the existing cache database.
class CreateRequestRateLimitCounters < ActiveRecord::Migration[8.1]
  def change
    create_table :request_rate_limit_counters do |table|
      table.string :counter_key, limit: 64, null: false, collation: 'ascii_bin'
      table.bigint :count, null: false, default: 0
      table.bigint :expires_at, null: false
      table.index :counter_key, unique: true
      table.timestamps
      table.index :expires_at
    end
  end
end
