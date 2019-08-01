# == Schema Information
#
# Table name: organization_ip_pools
#
#  id              :bigint(8)        not null, primary key
#  organization_id :integer
#  ip_pool_id      :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

class OrganizationIPPool < ApplicationRecord
  belongs_to :organization
  belongs_to :ip_pool
end
