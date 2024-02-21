# frozen_string_literal: true

# == Schema Information
#
# Table name: address_endpoints
#
#  id           :integer          not null, primary key
#  address      :string(255)
#  last_used_at :datetime
#  uuid         :string(255)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  server_id    :integer
#
FactoryBot.define do
  factory :address_endpoint do
    server
    sequence(:address) { |n| "test#{n}@example.com" }
  end
end
