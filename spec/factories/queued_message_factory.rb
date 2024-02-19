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
    domain { "example.com" }

    transient do
      message { nil }
    end

    after(:build) do |message, evaluator|
      if evaluator.message
        message.server = evaluator.message.server
        message.message_id = evaluator.message.id
        message.batch_key = evaluator.message.batch_key
        message.domain = evaluator.message.recipient_domain
        message.route_id = evaluator.message.route_id
      else
        message.server ||= create(:server)
        message.message_id ||= 0
      end
    end

    trait :locked do
      locked_by { "worker1" }
      locked_at { 5.minutes.ago }
    end

    trait :retry_in_future do
      attempts { 2 }
      retry_after { 1.hour.from_now }
    end
  end
end
