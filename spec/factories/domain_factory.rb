# frozen_string_literal: true

# == Schema Information
#
# Table name: domains
#
#  id                             :integer          not null, primary key
#  dkim_error                     :string(255)
#  dkim_identifier_string         :string(255)
#  dkim_key_size                  :integer
#  dkim_private_key               :text(65535)
#  dkim_status                    :string(255)
#  dmarc_error                    :string(255)
#  dmarc_status                   :string(255)
#  dns_checked_at                 :datetime
#  incoming                       :boolean          default(TRUE)
#  mta_sts_error                  :string(255)
#  mta_sts_max_age                :integer          default(86400)
#  mta_sts_mode                   :string(255)      default("none")
#  mta_sts_policy_id              :string(255)
#  mta_sts_status                 :string(255)
#  mx_error                       :string(255)
#  mx_status                      :string(255)
#  name                           :string(255)
#  outgoing                       :boolean          default(TRUE)
#  owner_type                     :string(255)
#  pending_dkim_identifier_string :string(255)
#  pending_dkim_key_created_at    :datetime
#  pending_dkim_key_notified_at   :datetime
#  pending_dkim_private_key       :text(65535)
#  return_path_error              :string(255)
#  return_path_status             :string(255)
#  spf_error                      :string(255)
#  spf_status                     :string(255)
#  tls_rpt_error                  :string(255)
#  tls_rpt_status                 :string(255)
#  use_for_any                    :boolean
#  uuid                           :string(255)
#  verification_method            :string(255)
#  verification_token             :string(255)
#  verified_at                    :datetime
#  created_at                     :datetime
#  updated_at                     :datetime
#  owner_id                       :integer
#  server_id                      :integer
#
# Indexes
#
#  index_domains_on_server_id  (server_id)
#  index_domains_on_uuid       (uuid)
#

FactoryBot.define do
  factory :domain do
    association :owner, factory: :organization
    sequence(:name) { |n| "example#{n}.com" }
    verification_method { "DNS" }
    verified_at { Time.now }

    trait :unverified do
      verified_at { nil }
    end

    trait :dns_all_ok do
      spf_status { "OK" }
      dkim_status { "OK" }
      mx_status { "OK" }
      return_path_status { "OK" }
    end
  end

  factory :organization_domain, parent: :domain do
    association :owner, factory: :organization
  end
end
