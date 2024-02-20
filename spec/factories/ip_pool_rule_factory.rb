# frozen_string_literal: true

FactoryBot.define do
  factory :ip_pool_rule do
    owner factory: :organization
    ip_pool
    to_text { "google.com" }

    after(:build) do |ip_pool_rule|
      if ip_pool_rule.ip_pool.organizations.empty? && ip_pool_rule.owner.is_a?(Organization)
        ip_pool_rule.ip_pool.organizations << ip_pool_rule.owner
      end
    end
  end
end
