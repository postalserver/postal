# frozen_string_literal: true

class CreateControlAPIKeys < ActiveRecord::Migration[7.0]

  def change
    create_table :control_api_keys do |t|
      t.string :uuid, null: false
      t.string :name, null: false
      t.string :token_digest, null: false
      t.text :scopes, null: false
      t.references :organization, type: :integer, foreign_key: true
      t.datetime :last_used_at
      t.datetime :expires_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :control_api_keys, :uuid, unique: true
    add_index :control_api_keys, :token_digest, unique: true
  end

end
