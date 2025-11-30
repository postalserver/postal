# frozen_string_literal: true

# == Schema Information
#
# Table name: management_api_keys
#
#  id              :integer          not null, primary key
#  uuid            :string(36)       not null
#  name            :string           not null
#  key             :string(48)       not null
#  description     :text
#  organization_id :integer
#  super_admin     :boolean          default(FALSE), not null
#  enabled         :boolean          default(TRUE), not null
#  request_count   :bigint           default(0), not null
#  last_used_at    :datetime
#  last_used_ip    :string
#  expires_at      :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

FactoryBot.define do
  factory :management_api_key do
    name { "Test API Key" }
    super_admin { true }

    trait :super_admin do
      super_admin { true }
      organization { nil }
    end

    trait :organization_scoped do
      super_admin { false }
      association :organization
    end

    trait :disabled do
      enabled { false }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
