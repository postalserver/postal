# frozen_string_literal: true

# == Schema Information
#
# Table name: management_api_keys
#
#  id              :integer          not null, primary key
#  uuid            :string(255)
#  name            :string(255)
#  key             :string(255)
#  description     :text
#  super_admin     :boolean          default(FALSE)
#  organization_id :integer
#  last_used_at    :datetime
#  last_used_ip    :string(255)
#  request_count   :integer          default(0)
#  enabled         :boolean          default(TRUE)
#  permissions     :json
#  expires_at      :datetime
#  created_at      :datetime
#  updated_at      :datetime
#

FactoryBot.define do
  factory :management_api_key do
    sequence(:name) { |n| "API Key #{n}" }
    description { "Test API Key" }
    enabled { true }
    super_admin { false }
    association :organization

    trait :super_admin do
      super_admin { true }
      organization { nil }
    end

    trait :disabled do
      enabled { false }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
