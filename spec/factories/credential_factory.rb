# frozen_string_literal: true

FactoryBot.define do
  factory :credential do
    server
    name { "Example Credential" }
    type { "API" }
  end
end
