# frozen_string_literal: true

# == Schema Information
#
# Table name: ip_addresses
#
#  id         :integer          not null, primary key
#  hostname   :string(255)
#  ipv4       :string(255)
#  ipv6       :string(255)
#  priority   :integer
#  created_at :datetime
#  updated_at :datetime
#  ip_pool_id :integer
#
FactoryBot.define do
  factory :ip_address do
    ip_pool
    ipv4 { "10.0.0.1" }
    ipv6 { "2001:0db8:85a3:0000:0000:8a2e:0370:7334" }
    hostname { "ip.example.com" }
  end
end
