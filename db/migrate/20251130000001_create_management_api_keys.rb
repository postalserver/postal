# frozen_string_literal: true

class CreateManagementApiKeys < ActiveRecord::Migration[7.0]

  def change
    create_table "management_api_keys", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
      t.string   "uuid", limit: 36, null: false
      t.string   "name", null: false
      t.string   "key", limit: 48, null: false
      t.text     "description"
      t.integer  "organization_id"
      t.boolean  "super_admin", default: false, null: false
      t.boolean  "enabled", default: true, null: false
      t.bigint   "request_count", default: 0, null: false
      t.datetime "last_used_at", precision: 6
      t.string   "last_used_ip"
      t.datetime "expires_at", precision: 6
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.index ["uuid"], name: "index_management_api_keys_on_uuid", unique: true
      t.index ["key"], name: "index_management_api_keys_on_key", unique: true
      t.index ["organization_id"], name: "index_management_api_keys_on_organization_id"
      t.index ["enabled"], name: "index_management_api_keys_on_enabled"
    end

    add_foreign_key "management_api_keys", "organizations", on_delete: :cascade
  end

end
