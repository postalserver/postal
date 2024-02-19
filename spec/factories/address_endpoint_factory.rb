# frozen_string_literal: true

FactoryBot.define do
  factory :address_endpoint do
    server
    sequence(:address) { |n| "test#{n}@example.com" }
  end
end
