# frozen_string_literal: true

class ControlAPIKey < ApplicationRecord

  include HasUUID

  TOKEN_PREFIX = "postal_cp_"
  TOKEN_BYTES = 32
  SCOPES = %w[
    platform:admin organizations:read organizations:write servers:read servers:write
    domains:read domains:write credentials:write usage:read
  ].freeze

  belongs_to :organization, optional: true
  has_many :idempotency_records, dependent: :destroy

  serialize :scopes, type: Array

  validates :name, :scopes, presence: true
  validates :token_digest, presence: true, uniqueness: true
  validate :scopes_are_supported
  validate :organization_scope_cannot_be_platform_admin

  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def self.issue!(name:, scopes:, organization: nil, expires_at: nil)
    token = "#{TOKEN_PREFIX}#{SecureRandom.urlsafe_base64(TOKEN_BYTES, false)}"
    key = create!(name: name, scopes: scopes, organization: organization, expires_at: expires_at, token_digest: digest(token))
    [key, token]
  end

  def self.authenticate(token)
    return if token.blank?

    digest = digest(token)
    candidate = active.find_by(token_digest: digest)
    return unless candidate
    return unless ActiveSupport::SecurityUtils.secure_compare(candidate.token_digest, digest)

    candidate.tap { |key| key.update_column(:last_used_at, Time.current) }
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def active?
    revoked_at.nil? && (expires_at.nil? || expires_at > Time.current)
  end

  def allows?(scope)
    scopes.include?("platform:admin") || scopes.include?(scope)
  end

  def platform_admin?
    scopes.include?("platform:admin") && organization_id.nil?
  end

  private

  def scopes_are_supported
    invalid = scopes.to_a - SCOPES
    errors.add(:scopes, "contain unsupported values") if invalid.any?
  end

  def organization_scope_cannot_be_platform_admin
    return unless organization_id && scopes.to_a.include?("platform:admin")

    errors.add(:scopes, "cannot include platform:admin for an organization-scoped key")
  end

end
