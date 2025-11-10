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

      # If we still don't have a user and auto creation is enabled, create one from the OIDC details.
      if user.nil?
        if config.auto_create_users?
          user = auto_create_user_from_oidc(uid, config, oidc_name, oidc_email_address, logger)
        else
          logger&.debug "OIDC auto user creation disabled; not creating user for #{oidc_email_address || uid}"
        end
        return if user.nil?
      end

      # otherwise, let's update our user as appropriate
      user.oidc_uid = uid
      user.oidc_issuer = config.issuer
      user.email_address = oidc_email_address if oidc_email_address.present?
      if oidc_name.present?
        user.first_name, user.last_name = derive_user_names_from_oidc(oidc_name, user.email_address)
      end
      user.password = nil
      user.save!

      # return the user
      user
    end

    private

    def auto_create_user_from_oidc(uid, config, oidc_name, oidc_email_address, logger)
      unless oidc_email_address.present?
        logger&.warn "OIDC auto user creation failed for UID #{uid}: no e-mail address provided"
        return nil
      end

      first_name, last_name = derive_user_names_from_oidc(oidc_name, oidc_email_address)
      user = new(
        email_address: oidc_email_address,
        first_name: first_name,
        last_name: last_name
      )
      user.oidc_uid = uid
      user.oidc_issuer = config.issuer
      user.password = nil
      user.save!
      logger&.info "OIDC auto user creation succeeded for #{oidc_email_address} (user ID: #{user.id}) with Firstname: #{first_name}, Lastname: #{last_name}"
      auto_create_organization_for(user, config, logger) if config.auto_create_organization?
      user
    rescue ActiveRecord::RecordInvalid => e
      logger&.error "OIDC auto user creation failed for #{oidc_email_address}: #{e.message}"
      nil
    end

    def derive_user_names_from_oidc(oidc_name, oidc_email_address)
      raw_name = oidc_name.to_s.strip
      if raw_name.present?
        first_name, last_name = raw_name.split(/\s+/, 2)
      else
        local_part = oidc_email_address.to_s.split("@", 2).first.to_s
        fallback_name = local_part.tr("._-", " ").strip
        first_name, last_name = fallback_name.split(/\s+/, 2)
      end

      first_name = first_name.presence || "OIDC"
      last_name = last_name.presence || first_name
      [first_name, last_name]
    end

    def auto_create_organization_for(user, config, logger)
      organization_name = config.auto_created_organization_name.presence || "My organization"
      organization = Organization.new(name: organization_name, owner: user)
      organization.save!
      organization.organization_users.create!(user: user, admin: true, all_servers: true)
      logger&.info "OIDC auto organization creation succeeded for user #{user.id} (organization ID: #{organization.id})"
      organization
    rescue ActiveRecord::RecordInvalid => e
      logger&.error "OIDC auto organization creation failed for user #{user.id}: #{e.message}"
      nil
    end

  end

end
