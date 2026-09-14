# frozen_string_literal: true

FactoryBot.define do
  factory :organization_user do
    organization
    user factory: :user
    admin { false }
    read_only { false }
    all_servers { true }
  end
end
