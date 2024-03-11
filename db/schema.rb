# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2024_03_11_205229) do
  create_table "additional_route_endpoints", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "route_id"
    t.string "endpoint_type"
    t.integer "endpoint_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "address_endpoints", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "server_id"
    t.string "uuid"
    t.string "address"
    t.datetime "last_used_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "authie_sessions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "token"
    t.string "browser_id"
    t.integer "user_id"
    t.boolean "active", default: true
    t.text "data"
    t.datetime "expires_at", precision: nil
    t.datetime "login_at", precision: nil
    t.string "login_ip"
    t.datetime "last_activity_at", precision: nil
    t.string "last_activity_ip"
    t.string "last_activity_path"
    t.string "user_agent"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "user_type"
    t.integer "parent_id"
    t.datetime "two_factored_at", precision: nil
    t.string "two_factored_ip"
    t.integer "requests", default: 0
    t.datetime "password_seen_at", precision: nil
    t.string "token_hash"
    t.string "host"
    t.boolean "skip_two_factor", default: false
    t.string "login_ip_country"
    t.string "two_factored_ip_country"
    t.string "last_activity_ip_country"
    t.index ["browser_id"], name: "index_authie_sessions_on_browser_id", length: 8
    t.index ["token"], name: "index_authie_sessions_on_token", length: 8
    t.index ["token_hash"], name: "index_authie_sessions_on_token_hash", length: 8
    t.index ["user_id"], name: "index_authie_sessions_on_user_id"
  end

  create_table "credentials", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "server_id"
    t.string "key"
    t.string "type"
    t.string "name"
    t.text "options"
    t.datetime "last_used_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "hold", default: false
    t.string "uuid"
  end

  create_table "domains", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "server_id"
    t.string "uuid"
    t.string "name"
    t.string "verification_token"
    t.string "verification_method"
    t.datetime "verified_at", precision: nil
    t.text "dkim_private_key"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "dns_checked_at"
    t.string "spf_status"
    t.string "spf_error"
    t.string "dkim_status"
    t.string "dkim_error"
    t.string "mx_status"
    t.string "mx_error"
    t.string "return_path_status"
    t.string "return_path_error"
    t.boolean "outgoing", default: true
    t.boolean "incoming", default: true
    t.string "owner_type"
    t.integer "owner_id"
    t.string "dkim_identifier_string"
    t.boolean "use_for_any"
    t.index ["server_id"], name: "index_domains_on_server_id"
    t.index ["uuid"], name: "index_domains_on_uuid", length: 8
  end

  create_table "http_endpoints", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "server_id"
    t.string "uuid"
    t.string "name"
    t.string "url"
    t.string "encoding"
    t.string "format"
    t.boolean "strip_replies", default: false
    t.text "error"
    t.datetime "disabled_until"
    t.datetime "last_used_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "include_attachments", default: true
    t.integer "timeout"
  end

  create_table "ip_addresses", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "ip_pool_id"
    t.string "ipv4"
    t.string "ipv6"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "hostname"
    t.integer "priority"
  end

  create_table "ip_pool_rules", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "uuid"
    t.string "owner_type"
    t.integer "owner_id"
    t.integer "ip_pool_id"
    t.text "from_text"
    t.text "to_text"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "ip_pools", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "name"
    t.string "uuid"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "default", default: false
    t.index ["uuid"], name: "index_ip_pools_on_uuid", length: 8
  end

  create_table "organization_ip_pools", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "organization_id"
    t.integer "ip_pool_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "organization_users", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "organization_id"
    t.integer "user_id"
    t.datetime "created_at"
    t.boolean "admin", default: false
    t.boolean "all_servers", default: true
    t.string "user_type"
  end

  create_table "organizations", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "uuid"
    t.string "name"
    t.string "permalink"
    t.string "time_zone"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "ip_pool_id"
    t.integer "owner_id"
    t.datetime "deleted_at"
    t.datetime "suspended_at"
    t.string "suspension_reason"
    t.index ["permalink"], name: "index_organizations_on_permalink", length: 8
    t.index ["uuid"], name: "index_organizations_on_uuid", length: 8
  end

  create_table "queued_messages", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "server_id"
    t.integer "message_id"
    t.string "domain"
    t.string "locked_by"
    t.datetime "locked_at"
    t.datetime "retry_after", precision: nil
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "ip_address_id"
    t.integer "attempts", default: 0
    t.integer "route_id"
    t.boolean "manual", default: false
    t.string "batch_key"
    t.index ["domain"], name: "index_queued_messages_on_domain", length: 8
    t.index ["message_id"], name: "index_queued_messages_on_message_id"
    t.index ["server_id"], name: "index_queued_messages_on_server_id"
  end

  create_table "routes", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "uuid"
    t.integer "server_id"
    t.integer "domain_id"
    t.integer "endpoint_id"
    t.string "endpoint_type"
    t.string "name"
    t.string "spam_mode"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "token"
    t.string "mode"
    t.index ["token"], name: "index_routes_on_token", length: 6
  end

  create_table "scheduled_tasks", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "next_run_after", precision: nil
    t.index ["name"], name: "index_scheduled_tasks_on_name", unique: true
  end

  create_table "servers", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "organization_id"
    t.string "uuid"
    t.string "name"
    t.string "mode"
    t.integer "ip_pool_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "permalink"
    t.integer "send_limit"
    t.datetime "deleted_at"
    t.integer "message_retention_days"
    t.integer "raw_message_retention_days"
    t.integer "raw_message_retention_size"
    t.boolean "allow_sender", default: false
    t.string "token"
    t.datetime "send_limit_approaching_at"
    t.datetime "send_limit_approaching_notified_at"
    t.datetime "send_limit_exceeded_at"
    t.datetime "send_limit_exceeded_notified_at"
    t.decimal "spam_threshold", precision: 8, scale: 2
    t.decimal "spam_failure_threshold", precision: 8, scale: 2
    t.string "postmaster_address"
    t.datetime "suspended_at"
    t.decimal "outbound_spam_threshold", precision: 8, scale: 2
    t.text "domains_not_to_click_track"
    t.string "suspension_reason"
    t.boolean "log_smtp_data", default: false
    t.boolean "privacy_mode", default: false
    t.index ["organization_id"], name: "index_servers_on_organization_id"
    t.index ["permalink"], name: "index_servers_on_permalink", length: 6
    t.index ["token"], name: "index_servers_on_token", length: 6
    t.index ["uuid"], name: "index_servers_on_uuid", length: 8
  end

  create_table "smtp_endpoints", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "server_id"
    t.string "uuid"
    t.string "name"
    t.string "hostname"
    t.string "ssl_mode"
    t.integer "port"
    t.text "error"
    t.datetime "disabled_until"
    t.datetime "last_used_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "statistics", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "total_messages", default: 0
    t.bigint "total_outgoing", default: 0
    t.bigint "total_incoming", default: 0
  end

  create_table "track_certificates", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "domain"
    t.text "certificate"
    t.text "intermediaries"
    t.text "key"
    t.datetime "expires_at", precision: nil
    t.datetime "renew_after", precision: nil
    t.string "verification_path"
    t.string "verification_string"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["domain"], name: "index_track_certificates_on_domain", length: 8
  end

  create_table "track_domains", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "uuid"
    t.integer "server_id"
    t.integer "domain_id"
    t.string "name"
    t.datetime "dns_checked_at", precision: nil
    t.string "dns_status"
    t.string "dns_error"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "ssl_enabled", default: true
    t.boolean "track_clicks", default: true
    t.boolean "track_loads", default: true
    t.text "excluded_click_domains"
  end

  create_table "user_invites", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "uuid"
    t.string "email_address"
    t.datetime "expires_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["uuid"], name: "index_user_invites_on_uuid", length: 12
  end

  create_table "users", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "uuid"
    t.string "first_name"
    t.string "last_name"
    t.string "email_address"
    t.string "password_digest"
    t.string "time_zone"
    t.string "email_verification_token"
    t.datetime "email_verified_at", precision: nil
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "password_reset_token"
    t.datetime "password_reset_token_valid_until", precision: nil
    t.boolean "admin", default: false
    t.string "oidc_uid"
    t.string "oidc_issuer"
    t.index ["email_address"], name: "index_users_on_email_address", length: 8
    t.index ["uuid"], name: "index_users_on_uuid", length: 8
  end

  create_table "webhook_events", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "webhook_id"
    t.string "event"
    t.datetime "created_at"
    t.index ["webhook_id"], name: "index_webhook_events_on_webhook_id"
  end

  create_table "webhook_requests", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "server_id"
    t.integer "webhook_id"
    t.string "url"
    t.string "event"
    t.string "uuid"
    t.text "payload"
    t.integer "attempts", default: 0
    t.datetime "retry_after"
    t.text "error"
    t.datetime "created_at"
    t.string "locked_by"
    t.datetime "locked_at", precision: nil
    t.index ["locked_by"], name: "index_webhook_requests_on_locked_by"
  end

  create_table "webhooks", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "server_id"
    t.string "uuid"
    t.string "name"
    t.string "url"
    t.datetime "last_used_at", precision: nil
    t.boolean "all_events", default: false
    t.boolean "enabled", default: true
    t.boolean "sign", default: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["server_id"], name: "index_webhooks_on_server_id"
  end

  create_table "worker_roles", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "role"
    t.string "worker"
    t.datetime "acquired_at", precision: nil
    t.index ["role"], name: "index_worker_roles_on_role", unique: true
  end

end
