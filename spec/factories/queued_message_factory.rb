# frozen_string_literal: true

# == Schema Information
#
# Table name: queued_messages
#
#  id            :integer          not null, primary key
#  attempts      :integer          default(0)
#  batch_key     :string(255)
#  domain        :string(255)
#  locked_at     :datetime
#  locked_by     :string(255)
#  manual        :boolean          default(FALSE)
#  retry_after   :datetime
#  created_at    :datetime
#  updated_at    :datetime
#  ip_address_id :integer
#  message_id    :integer
#  route_id      :integer
#  server_id     :integer
#
# Indexes
#
#  index_queued_messages_on_domain      (domain)
#  index_queued_messages_on_message_id  (message_id)
#  index_queued_messages_on_server_id   (server_id)
#
FactoryBot.define do
  factory :queued_message do
    server
    message_id { 1234 }
    domain { "example.com" }
    batch_key { nil }

    trait :locked do
      locked_by { "worker1" }
      locked_at { 5.minutes.ago }
    end
  end
end
