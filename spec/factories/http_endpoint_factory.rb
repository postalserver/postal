# frozen_string_literal: true

FactoryBot.define do
  factory :http_endpoint do
    server
    name { "HTTP endpoint" }
    url { "https://example.com/endpoint" }
    encoding { "BodyAsJSON" }
    format { "Hash" }
  end
end
