# frozen_string_literal: true

module ManagementAPI
  class UsersController < BaseController

    # GET /management/api/v1/users
    # List all users
    #
    # Params:
    #   admin (optional) - filter by admin status (true/false)
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "users": [
    #       { "uuid": "xxx", "email_address": "user@example.com", ... }
    #     ]
    #   }
    # }
    def index
      users = User.all

      if api_params[:admin].present?
        users = users.where(admin: api_params[:admin] == "true")
      end

      render_success(
        users: users.map { |u| user_to_hash(u) }
      )
    end

    # GET /management/api/v1/users/:uuid
    # Get a specific user by UUID or email
    def show
      user = find_user(params[:id])
      render_success(
        user: user_to_hash(user, include_organizations: true)
      )
    end

    # POST /management/api/v1/users
    # Create a new user
    #
    # Required params:
    #   email_address - user email
    #   first_name - first name
    #   last_name - last name
    #
    # Optional params:
    #   password - password (min 8 chars)
    #   admin - make user a global admin (default: false)
    #   time_zone - user timezone (default: UTC)
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "user": { ... }
    #   }
    # }
    def create
      user = User.new(
        email_address: api_params[:email_address],
        first_name: api_params[:first_name],
        last_name: api_params[:last_name],
        admin: api_params[:admin] == true || api_params[:admin] == "true",
        time_zone: api_params[:time_zone] || "UTC"
      )

      if api_params[:password].present?
        user.password = api_params[:password]
        user.password_confirmation = api_params[:password]
      end

      user.save!

      render_success(user: user_to_hash(user))
    end

    # PATCH /management/api/v1/users/:uuid
    # Update user settings
    #
    # Params:
    #   email_address - user email
    #   first_name - first name
    #   last_name - last name
    #   password - new password (min 8 chars)
    #   admin - global admin status
    #   time_zone - user timezone
    def update
      user = find_user(params[:id])

      update_params = {}
      update_params[:email_address] = api_params[:email_address] if api_params[:email_address].present?
      update_params[:first_name] = api_params[:first_name] if api_params[:first_name].present?
      update_params[:last_name] = api_params[:last_name] if api_params[:last_name].present?
      update_params[:time_zone] = api_params[:time_zone] if api_params[:time_zone].present?

      if api_params.key?(:admin)
        update_params[:admin] = api_params[:admin] == true || api_params[:admin] == "true"
      end

      if api_params[:password].present?
        update_params[:password] = api_params[:password]
        update_params[:password_confirmation] = api_params[:password]
      end

      user.update!(update_params)

      render_success(user: user_to_hash(user))
    end

    # DELETE /management/api/v1/users/:uuid
    # Delete a user
    def destroy
      user = find_user(params[:id])

      # Don't allow deleting last admin
      if user.admin? && User.where(admin: true).count == 1
        render_error "LastAdmin", message: "Cannot delete the last admin user"
        return
      end

      user.destroy!
      render_success(message: "User '#{user.email_address}' has been deleted")
    end

    # POST /management/api/v1/users/:uuid/reset_password
    # Generate password reset token for user
    def reset_password
      user = find_user(params[:id])

      if user.oidc?
        render_error "OIDCUser", message: "Cannot reset password for OIDC users"
        return
      end

      token = SecureRandom.alphanumeric(24)
      user.update!(
        password_reset_token: token,
        password_reset_token_valid_until: 1.hour.from_now
      )

      render_success(
        message: "Password reset token generated",
        reset_token: token,
        valid_until: user.password_reset_token_valid_until
      )
    end

    private

    def find_user(identifier)
      User.find_by!(uuid: identifier)
    rescue ActiveRecord::RecordNotFound
      User.find_by!(email_address: identifier)
    end

    def user_to_hash(user, include_organizations: false)
      hash = {
        uuid: user.uuid,
        email_address: user.email_address,
        first_name: user.first_name,
        last_name: user.last_name,
        name: user.name,
        admin: user.admin?,
        time_zone: user.time_zone,
        oidc: user.oidc?,
        email_verified: user.email_verified_at.present?,
        created_at: user.created_at,
        updated_at: user.updated_at
      }

      if include_organizations
        hash[:organizations] = user.organizations.map do |org|
          ou = user.organization_users.find_by(organization: org)
          {
            permalink: org.permalink,
            name: org.name,
            admin: ou&.admin?,
            all_servers: ou&.all_servers?
          }
        end
      end

      hash
    end

  end
end
