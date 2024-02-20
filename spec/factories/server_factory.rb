# frozen_string_literal: true

# == Schema Information
#
# Table name: servers
#
#  id                                 :integer          not null, primary key
#  allow_sender                       :boolean          default(FALSE)
#  deleted_at                         :datetime
#  domains_not_to_click_track         :text(65535)
#  log_smtp_data                      :boolean          default(FALSE)
#  message_retention_days             :integer
#  mode                               :string(255)
#  name                               :string(255)
#  outbound_spam_threshold            :decimal(8, 2)
#  permalink                          :string(255)
#  postmaster_address                 :string(255)
#  privacy_mode                       :boolean          default(FALSE)
#  raw_message_retention_days         :integer
#  raw_message_retention_size         :integer
#  send_limit                         :integer
#  send_limit_approaching_at          :datetime
#  send_limit_approaching_notified_at :datetime
#  send_limit_exceeded_at             :datetime
#  send_limit_exceeded_notified_at    :datetime
#  spam_failure_threshold             :decimal(8, 2)
#  spam_threshold                     :decimal(8, 2)
#  suspended_at                       :datetime
#  suspension_reason                  :string(255)
#  token                              :string(255)
#  uuid                               :string(255)
#  created_at                         :datetime
#  updated_at                         :datetime
#  ip_pool_id                         :integer
#  organization_id                    :integer
#
# Indexes
#
#  index_servers_on_organization_id  (organization_id)
#  index_servers_on_permalink        (permalink)
#  index_servers_on_token            (token)
#  index_servers_on_uuid             (uuid)
#

FactoryBot.define do
  factory :server do
    association :organization
    name { "Mail Server" }
    mode { "Live" }
    provision_database { false }
    sequence(:permalink) { |n| "server#{n}" }

    trait :suspended do
      suspended_at { Time.current }
      suspension_reason { "Test Reason" }
    end

    trait :exceeded_send_limit do
      send_limit_approaching_at { 5.minutes.ago }
      send_limit_exceeded_at { 1.minute.ago }
    end
  end
end
