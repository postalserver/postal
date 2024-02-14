# frozen_string_literal: true

# == Schema Information
#
# Table name: webhook_requests
#
#  id          :integer          not null, primary key
#  attempts    :integer          default(0)
#  error       :text(65535)
#  event       :string(255)
#  locked_at   :datetime
#  locked_by   :string(255)
#  payload     :text(65535)
#  retry_after :datetime
#  url         :string(255)
#  uuid        :string(255)
#  created_at  :datetime
#  server_id   :integer
#  webhook_id  :integer
#
# Indexes
#
#  index_webhook_requests_on_locked_by  (locked_by)
#
FactoryBot.define do
  factory :webhook_request do
    webhook
    url { "https://example.com" }
    event { "ExampleEvent" }
    payload { { "hello" => "world" } }

    before(:create) do |webhook_request|
      webhook_request.server = webhook_request.webhook&.server
    end

    trait :locked do
      locked_by { "test" }
      locked_at { 5.minutes.ago }
    end
  end
end
