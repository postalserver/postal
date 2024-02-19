# frozen_string_literal: true

FactoryBot.define do
  factory :smtp_endpoint do
    server
    name { "Example SMTP Endpoint" }
    hostname { "example.com" }
    ssl_mode { "None" }
    port { 25 }
  end
end
