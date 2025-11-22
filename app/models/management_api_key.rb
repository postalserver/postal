# frozen_string_literal: true

# == Schema Information
#
# Table name: management_api_keys
#
#  id              :integer          not null, primary key
#  uuid            :string(255)
#  name            :string(255)
#  key             :string(255)
#  description     :text
#  super_admin     :boolean          default(FALSE)
#  organization_id :integer
#  last_used_at    :datetime
#  last_used_ip    :string(255)
#  request_count   :integer          default(0)
#  enabled         :boolean          default(TRUE)
#  permissions     :json
#  expires_at      :datetime
#  created_at      :datetime
#  updated_at      :datetime
#

class ManagementApiKey < ApplicationRecord

  include HasUUID

  belongs_to :organization, optional: true

  validates :name, presence: true
  validates :key, presence: true, uniqueness: { case_sensitive: false }

  before_validation :generate_key, on: :create

  # Default permissions structure
  DEFAULT_PERMISSIONS = {
    organizations: { read: true, write: true, delete: false },
    servers: { read: true, write: true, delete: false },
    domains: { read: true, write: true, delete: true },
    users: { read: true, write: false, delete: false },
    credentials: { read: true, write: true, delete: true },
    routes: { read: true, write: true, delete: true },
    webhooks: { read: true, write: true, delete: true },
    messages: { read: true, write: false, delete: false },
    system: { read: true, write: false, delete: false }
  }.freeze

  def generate_key
    return if key.present?

    self.key = "mgmt_#{SecureRandom.alphanumeric(40)}"
  end

  def to_param
    uuid
  end

  def use(ip_address = nil)
    update_columns(
      last_used_at: Time.current,
      last_used_ip: ip_address,
      request_count: request_count + 1
    )
  end

  def active?
    enabled? && !expired?
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def can?(resource, action)
    return true if super_admin?

    perms = permissions || DEFAULT_PERMISSIONS
    resource_perms = perms[resource.to_s] || perms[resource.to_sym]
    return false unless resource_perms

    resource_perms[action.to_s] || resource_perms[action.to_sym] || false
  end

  def accessible_organizations
    if super_admin?
      Organization.present
    elsif organization_id.present?
      Organization.where(id: organization_id).present
    else
      Organization.none
    end
  end

  def accessible_servers
    if super_admin?
      Server.joins(:organization).where(organizations: { deleted_at: nil })
    elsif organization_id.present?
      Server.joins(:organization).where(organization_id: organization_id, organizations: { deleted_at: nil })
    else
      Server.none
    end
  end

  class << self
    def authenticate(key)
      return nil if key.blank?

      api_key = find_by(key: key)
      return nil if api_key.nil?
      return nil unless api_key.active?

      api_key
    end
  end

end
