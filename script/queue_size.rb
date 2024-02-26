#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/postal/config"
require "mysql2"

client = Mysql2::Client.new(
  host: Postal::Config.main_db.host,
  username: Postal::Config.main_db.username,
  password: Postal::Config.main_db.password,
  port: Postal::Config.main_db.port,
  database: Postal::Config.main_db.database
)
result = client.query("SELECT COUNT(id) as size FROM `queued_messages` WHERE retry_after IS NULL OR " \
                      "retry_after <= ADDTIME(UTC_TIMESTAMP(), '30') AND locked_at IS NULL")
puts result.to_a.first["size"]
