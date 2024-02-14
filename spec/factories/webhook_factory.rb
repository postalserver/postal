# frozen_string_literal: true

FactoryBot.define do
  factory :webhook do
    server
    name { "Example Webhook" }
    url { "https://example.com" }
    all_events { true }
  end
end
