# frozen_string_literal: true

module HasAuthentication

  extend ActiveSupport::Concern

  included do
    has_secure_password validations: false

    validates :password, length: { minimum: 8, allow_blank: true }
    validates :password, confirmation: { allow_blank: true }
    validate :validate_password_presence

    before_save :clear_password_reset_token_on_password_change

    scope :with_password, -> { where.not(password_digest: nil) }
  end

  class_methods do
    def authenticate(email_address, password)
      user = find_by(email_address: email_address)
      raise Postal::Errors::AuthenticationError, "InvalidEmailAddress" if user.nil?
      raise Postal::Errors::AuthenticationError, "InvalidPassword" unless user.authenticate(password)

      user
    end
  end

  def authenticate_with_previous_password_first(unencrypted_password)
    if password_digest_changed?
      BCrypt::Password.new(password_digest_was).is_password?(unencrypted_password) && self
    else
      authenticate(unencrypted_password)
    end
  end

  def begin_password_reset(return_to = nil)
    if Postal::Config.oidc.enabled? && (oidc_uid.present? || password_digest.blank?)
      raise Postal::Error, "User has OIDC enabled, password resets are not supported"
    end

    self.password_reset_token = SecureRandom.alphanumeric(24)
    self.password_reset_token_valid_until = 1.day.from_now
    save!
    AppMailer.password_reset(self, return_to).deliver
  end

  private

  def clear_password_reset_token_on_password_change
    return unless password_digest_changed?

    self.password_reset_token = nil
    self.password_reset_token_valid_until = nil
  end

  def validate_password_presence
    return if password_digest.present? || Postal::Config.oidc.enabled?

    errors.add :password, :blank
  end

end

# -*- SkipSchemaAnnotations
