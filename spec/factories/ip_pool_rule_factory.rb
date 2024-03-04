# frozen_string_literal: true

# == Schema Information
#
# Table name: ip_pool_rules
#
#  id         :integer          not null, primary key
#  from_text  :text(65535)
#  owner_type :string(255)
#  to_text    :text(65535)
#  uuid       :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  ip_pool_id :integer
#  owner_id   :integer
#
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
