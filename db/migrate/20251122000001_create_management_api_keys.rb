# frozen_string_literal: true

class CreateManagementApiKeys < ActiveRecord::Migration[7.1]
  def change
    create_table :management_api_keys do |t|
      t.string :uuid, null: false
      t.string :name, null: false
      t.string :key, null: false
      t.text :description
      t.boolean :super_admin, default: false
      t.references :organization, foreign_key: true
      t.datetime :last_used_at
      t.string :last_used_ip
      t.integer :request_count, default: 0
      t.boolean :enabled, default: true
      t.json :permissions
      t.datetime :expires_at
      t.timestamps
    end

    add_index :management_api_keys, :uuid, unique: true
    add_index :management_api_keys, :key, unique: true
    add_index :management_api_keys, :enabled
  end
end
