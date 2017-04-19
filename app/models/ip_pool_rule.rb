# == Schema Information
#
# Table name: ip_pool_rules
#
#  id         :integer          not null, primary key
#  uuid       :string(255)
#  owner_type :string(255)
#  owner_id   :integer
#  ip_pool_id :integer
#  from_text  :text(65535)
#  to_text    :text(65535)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class IPPoolRule < ApplicationRecord

  include HasUUID

  belongs_to :owner, :polymorphic => true
  belongs_to :ip_pool

  validate :validate_from_and_to_addresses
  validate :validate_ip_pool_belongs_to_organization

  def from
    from_text ? from_text.gsub(/\r/, '').split(/\n/).map(&:strip) : []
  end

  def to
    to_text ? to_text.gsub(/\r/, '').split(/\n/).map(&:strip) : []
  end

  def apply_to_message?(message)
    if from.present? && message.headers['from'].present?
      from.each do |condition|
        if message.headers['from'].any? { |f| self.class.address_matches?(condition, f) }
          return true
        end
      end
    end

    if to.present? && message.rcpt_to.present?
      to.each do |condition|
        if self.class.address_matches?(condition, message.rcpt_to)
          return true
        end
      end
    end

    false
  end

  private

  def validate_from_and_to_addresses
    if self.from.empty? && self.to.empty?
      errors.add :base, "At least one rule condition must be specified"
    end
  end

  def validate_ip_pool_belongs_to_organization
    org = self.owner.is_a?(Organization) ? self.owner : self.owner.organization
    if self.ip_pool && self.ip_pool_id_changed? && !org.ip_pools.include?(self.ip_pool)
      errors.add :ip_pool_id, "must belong to the organization"
    end
  end

  def self.address_matches?(condition, address)
    address = Postal::Helpers.strip_name_from_address(address)
    if condition =~ /@/
      parts = address.split('@')
      domain, uname = parts.pop, parts.join('@')
      uname, _ = uname.split('+', 2)
      condition == "#{uname}@#{domain}"
    else
      # Match as a domain
      condition == address.split('@').last
    end
  end

end
