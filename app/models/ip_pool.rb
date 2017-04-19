# == Schema Information
#
# Table name: ip_pools
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  uuid       :string(255)
#  created_at :datetime
#  updated_at :datetime
#  default    :boolean          default(FALSE)
#  type       :string(255)
#
# Indexes
#
#  index_ip_pools_on_uuid  (uuid)
#

class IPPool < ApplicationRecord

  TYPES = ['Transactional', 'Bulk', 'Forwarding', 'Dedicated']

  include HasUUID

  validates :name, :presence => true

  has_many :ip_addresses, :dependent => :restrict_with_exception
  has_many :servers, :dependent => :restrict_with_exception
  has_many :organization_ip_pools, :dependent => :destroy
  has_many :organizations, :through => :organization_ip_pools

  scope :transactional, -> { where(:type => 'Transactional') }
  scope :bulk, -> { where(:type => 'Bulk') }
  scope :forwarding, -> { where(:type => 'Forwarding') }
  scope :dedicated, -> { where(:type => 'Dedicated') }

  def self.default
    where(:default => true).order(:id).first
  end

  def description
    desc = "#{name}"
    if self.type == 'Dedicated'
      desc += " (#{ip_addresses.map(&:ipv4).to_sentence})"
    end
    desc
  end

end
