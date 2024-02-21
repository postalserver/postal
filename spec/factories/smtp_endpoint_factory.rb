# frozen_string_literal: true

# == Schema Information
#
# Table name: smtp_endpoints
#
#  id             :integer          not null, primary key
#  disabled_until :datetime
#  error          :text(65535)
#  hostname       :string(255)
#  last_used_at   :datetime
#  name           :string(255)
#  port           :integer
#  ssl_mode       :string(255)
#  uuid           :string(255)
#  created_at     :datetime
#  updated_at     :datetime
#  server_id      :integer
#
FactoryBot.define do
  factory :smtp_endpoint do
    server
    name { "Example SMTP Endpoint" }
    hostname { "example.com" }
    ssl_mode { "None" }
    port { 25 }
  end
end
