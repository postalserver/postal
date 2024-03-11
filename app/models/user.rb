# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                               :integer          not null, primary key
#  admin                            :boolean          default(FALSE)
#  email_address                    :string(255)
#  email_verification_token         :string(255)
#  email_verified_at                :datetime
#  first_name                       :string(255)
#  last_name                        :string(255)
#  oidc_issuer                      :string(255)
#  oidc_uid                         :string(255)
#  password_digest                  :string(255)
#  password_reset_token             :string(255)
#  password_reset_token_valid_until :datetime
#  time_zone                        :string(255)
#  uuid                             :string(255)
#  created_at                       :datetime
#  updated_at                       :datetime
#
# Indexes
#
#  index_users_on_email_address  (email_address)
#  index_users_on_uuid           (uuid)
#

class User < ApplicationRecord

  include HasUUID
  include HasAuthentication

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email_address, presence: true, uniqueness: { case_sensitive: false }, format: { with: /@/, allow_blank: true }

  default_value :time_zone, -> { "UTC" }

  has_many :organization_users, dependent: :destroy, as: :user
  has_many :organizations, through: :organization_users

  def organizations_scope
    if admin?
      @organizations_scope ||= Organization.present
    else
      @organizations_scope ||= organizations.present
    end
  end

  def name
    "#{first_name} #{last_name}"
  end

  def password?
    password_digest.present?
  end

  def oidc?
    oidc_uid.present?
  end

  def to_param
    uuid
  end

  def email_tag
    "#{name} <#{email_address}>"
  end

  class << self

    # Lookup a user by email address
    #
    # @param email [String] the email address
    #
    # @return [User, nil] the user
    def [](email)
      find_by(email_address: email)
    end

    # Find a user based on an OIDC authentication hash
    #
    # @param auth [Hash] the authentication hash
    # @param logger [Logger] a logger to log debug information to
    #
    # @return [User, nil] the user
    def find_from_oidc(auth, logger: nil)
      config = Postal::Config.oidc

      uid = auth[config.uid_field]
      oidc_name = auth[config.name_field]
      oidc_email_address = auth[config.email_address_field]

      logger&.debug "got auth details from issuer: #{auth.inspect}"

      # look for an existing user with the same UID and OIDC issuer. If we find one,
      # this is the user we'll want to use.
      user = where(oidc_uid: uid, oidc_issuer: config.issuer).first

      if user
        logger&.debug "found user with UID #{uid} for issuer #{config.issuer} (user ID: #{user.id})"
      else
        logger&.debug "no user with UID #{uid} for issuer #{config.issuer}"
      end

      # if we don't have an existing user, we will look for users which have no OIDC
      # credentials but with a matching e-mail address.
      if user.nil? && oidc_email_address.present?
        user = where(oidc_uid: nil, email_address: oidc_email_address).first
        if user
          logger&.debug "found user with e-mail address #{oidc_email_address} (user ID: #{user.id})"
        else
          logger&.debug "no user with e-mail address #{oidc_email_address}"
        end
      end

      # now, if we still don't have a user, we're not going to create one so we'll just
      # return nil (we might auto create users in the future but not right now)
      return if user.nil?

      # otherwise, let's update our user as appropriate
      user.oidc_uid = uid
      user.oidc_issuer = config.issuer
      user.email_address = oidc_email_address if oidc_email_address.present?
      user.first_name, user.last_name = oidc_name.split(/\s+/, 2) if oidc_name.present?
      user.password = nil
      user.save!

      # return the user
      user
    end

  end

end
