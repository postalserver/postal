# frozen_string_literal: true

class CreateUsageRollups < ActiveRecord::Migration[7.0]

  def change
    create_table :usage_rollups do |t|
      t.references :organization, type: :integer, null: false, foreign_key: true
      t.integer :server_id, null: false, default: 0
      t.date :period_start, null: false
      t.string :granularity, null: false
      t.string :metric, null: false
      t.bigint :value, null: false, default: 0
      t.timestamps
    end

    add_index :usage_rollups, [:organization_id, :server_id, :period_start, :granularity, :metric], unique: true, name: "index_usage_rollups_on_metric_period"
  end

end
