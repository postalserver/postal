# frozen_string_literal: true

class CreateControlPlaneAuditAndIdempotencyRecords < ActiveRecord::Migration[7.0]

  def change
    create_table :audit_events do |t|
      t.string :actor_uuid
      t.string :organization_uuid
      t.string :resource_type, null: false
      t.string :resource_uuid
      t.string :action, null: false
      t.string :request_id
      t.string :source_ip
      t.text :before_metadata
      t.text :after_metadata
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :audit_events, [:organization_uuid, :occurred_at]
    add_index :audit_events, :request_id

    create_table :idempotency_records do |t|
      t.references :control_api_key, null: false, foreign_key: true
      t.string :key, null: false
      t.string :request_method, null: false
      t.string :request_path, null: false
      t.string :payload_digest, null: false
      t.integer :response_status
      t.text :response_body
      t.timestamps
    end

    add_index :idempotency_records, [:control_api_key_id, :key], unique: true, name: "index_idempotency_records_on_key_and_control_api_key"
  end

end
