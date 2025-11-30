# frozen_string_literal: true

# == Schema Information
#
# Table name: management_api_keys
#
#  id              :integer          not null, primary key
#  uuid            :string(36)       not null
#  name            :string           not null
#  key             :string(48)       not null
#  description     :text
#  organization_id :integer
#  super_admin     :boolean          default(FALSE), not null
#  enabled         :boolean          default(TRUE), not null
#  request_count   :bigint           default(0), not null
#  last_used_at    :datetime
#  last_used_ip    :string
#  expires_at      :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

class ManagementAPIKey < ApplicationRecord

  include HasUUID

  self.table_name = "management_api_keys"

  KEY_PREFIX = "mgmt_"

  belongs_to :organization, optional: true

  validates :name, presence: true
  validates :key, presence: true, uniqueness: { case_sensitive: false }
  validate :validate_organization_required_unless_super_admin

  before_validation :generate_key, on: :create

  scope :enabled, -> { where(enabled: true) }
  scope :active, -> { enabled.where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :super_admin, -> { where(super_admin: true) }
  scope :for_organization, ->(org) { where(organization: org) }

  def self.authenticate(key_value)
    return nil if key_value.blank?

    key = active.find_by(key: key_value)
    return nil unless key

    key
  end

  def generate_key
    return if persisted?

    self.key = KEY_PREFIX + SecureRandom.alphanumeric(40)
  end

  def use!(ip_address = nil)
    update_columns(
      request_count: request_count + 1,
      last_used_at: Time.current,
      last_used_ip: ip_address
    )
  end

  def active?
    enabled? && !expired?
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def can_access_organization?(org)
    return true if super_admin?
    return false if organization_id.nil?

    organization_id == org.id
  end

  def accessible_organizations
    if super_admin?
      Organization.present
    elsif organization
      Organization.where(id: organization_id).present
    else
      Organization.none
    end
  end

  def to_param
    uuid
  end

  def as_json_for_api(include_key: false)
    result = {
      uuid: uuid,
      name: name,
      description: description,
      super_admin: super_admin,
      organization_permalink: organization&.permalink,
      enabled: enabled,
      request_count: request_count,
      last_used_at: last_used_at&.iso8601,
      last_used_ip: last_used_ip,
      expires_at: expires_at&.iso8601,
      created_at: created_at.iso8601,
      updated_at: updated_at.iso8601
    }
    result[:key] = key if include_key
    result
  end

  private

  def validate_organization_required_unless_super_admin
    return if super_admin?
    return if organization_id.present?

    errors.add(:organization, "is required for non-super-admin keys")
  end

end
