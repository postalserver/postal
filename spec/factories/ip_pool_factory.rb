# frozen_string_literal: true

# == Schema Information
#
# Table name: ip_pools
#
#  id         :integer          not null, primary key
#  default    :boolean          default(FALSE)
#  name       :string(255)
#  uuid       :string(255)
#  created_at :datetime
#  updated_at :datetime
#
# Indexes
#
#  index_ip_pools_on_uuid  (uuid)
#
FactoryBot.define do
  factory :ip_pool do
    name { "Default Pool" }
    default { true }
  end
end
