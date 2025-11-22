# frozen_string_literal: true

module ManagementAPI
  class OrganizationUsersController < BaseController

    # GET /management/api/v1/organizations/:organization_id/users
    # List all users in an organization
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "users": [
    #       { "uuid": "xxx", "email_address": "user@example.com", "admin": true, "all_servers": true }
    #     ]
    #   }
    # }
    def index
      organization = find_organization(params[:organization_id])

      users = organization.organization_users.includes(:user).map do |ou|
        organization_user_to_hash(ou)
      end

      render_success(
        organization: organization.permalink,
        users: users
      )
    end

    # GET /management/api/v1/organizations/:organization_id/users/:uuid
    # Get a specific user in an organization
    def show
      organization = find_organization(params[:organization_id])
      user = User.find_by!(uuid: params[:id])
      ou = organization.organization_users.find_by!(user: user)

      render_success(
        organization: organization.permalink,
        user: organization_user_to_hash(ou)
      )
    end

    # POST /management/api/v1/organizations/:organization_id/users
    # Add a user to an organization
    #
    # Required params:
    #   user_uuid - UUID of user to add
    #
    # Optional params:
    #   admin - make user an organization admin (default: false)
    #   all_servers - give user access to all servers (default: true)
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "user": { ... }
    #   }
    # }
    def create
      organization = find_organization(params[:organization_id])
      user = User.find_by!(uuid: api_params[:user_uuid])

      # Check if user is already in organization
      if organization.organization_users.exists?(user: user)
        render_error "AlreadyMember", message: "User is already a member of this organization"
        return
      end

      ou = organization.organization_users.create!(
        user: user,
        admin: api_params[:admin] == true || api_params[:admin] == "true",
        all_servers: api_params[:all_servers] != false && api_params[:all_servers] != "false"
      )

      render_success(
        organization: organization.permalink,
        user: organization_user_to_hash(ou)
      )
    end

    # PATCH /management/api/v1/organizations/:organization_id/users/:uuid
    # Update user's role in an organization
    #
    # Params:
    #   admin - organization admin status
    #   all_servers - access to all servers
    def update
      organization = find_organization(params[:organization_id])
      user = User.find_by!(uuid: params[:id])
      ou = organization.organization_users.find_by!(user: user)

      # Don't allow demoting owner
      if organization.owner == user && api_params[:admin] == false
        render_error "CannotDemoteOwner", message: "Cannot demote organization owner"
        return
      end

      update_params = {}
      if api_params.key?(:admin)
        update_params[:admin] = api_params[:admin] == true || api_params[:admin] == "true"
      end
      if api_params.key?(:all_servers)
        update_params[:all_servers] = api_params[:all_servers] == true || api_params[:all_servers] == "true"
      end

      ou.update!(update_params)

      render_success(
        organization: organization.permalink,
        user: organization_user_to_hash(ou)
      )
    end

    # DELETE /management/api/v1/organizations/:organization_id/users/:uuid
    # Remove a user from an organization
    def destroy
      organization = find_organization(params[:organization_id])
      user = User.find_by!(uuid: params[:id])
      ou = organization.organization_users.find_by!(user: user)

      # Don't allow removing owner
      if organization.owner == user
        render_error "CannotRemoveOwner", message: "Cannot remove organization owner"
        return
      end

      ou.destroy!
      render_success(message: "User '#{user.email_address}' has been removed from organization")
    end

    # POST /management/api/v1/organizations/:organization_id/users/:uuid/make_owner
    # Transfer organization ownership
    def make_owner
      organization = find_organization(params[:organization_id])
      user = User.find_by!(uuid: params[:id])
      ou = organization.organization_users.find_by!(user: user)

      # Update old owner to regular admin
      if old_ou = organization.organization_users.find_by(user: organization.owner)
        old_ou.update!(admin: true, all_servers: true)
      end

      # Update new owner
      organization.update!(owner: user)
      ou.update!(admin: true, all_servers: true)

      render_success(
        message: "Ownership transferred to #{user.email_address}",
        organization: organization.permalink,
        new_owner: organization_user_to_hash(ou.reload)
      )
    end

    private

    def organization_user_to_hash(ou)
      user = ou.user
      {
        uuid: user.uuid,
        email_address: user.email_address,
        first_name: user.first_name,
        last_name: user.last_name,
        name: user.name,
        admin: ou.admin?,
        all_servers: ou.all_servers?,
        is_owner: ou.organization.owner == user,
        created_at: ou.created_at
      }
    end

  end
end
