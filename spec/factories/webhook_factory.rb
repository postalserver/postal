# frozen_string_literal: true

# == Schema Information
#
# Table name: webhooks
#
#  id           :integer          not null, primary key
#  all_events   :boolean          default(FALSE)
#  enabled      :boolean          default(TRUE)
#  last_used_at :datetime
#  name         :string(255)
#  sign         :boolean          default(TRUE)
#  url          :string(255)
#  uuid         :string(255)
#  created_at   :datetime
#  updated_at   :datetime
#  server_id    :integer
#
# Indexes
#
#  index_webhooks_on_server_id  (server_id)
#
FactoryBot.define do
  factory :webhook do
    server
    name { "Example Webhook" }
    url { "https://example.com" }
    all_events { true }
  end
end
