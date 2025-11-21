# frozen_string_literal: true

module ManagementAPI
  class OrganizationsController < BaseController

    # GET /management/api/v1/organizations
    # List all organizations
    def index
      organizations = Organization.includes(:owner, :servers).all

      render_success(
        organizations: organizations.map { |o| organization_to_hash(o) }
      )
    end

    # GET /management/api/v1/organizations/:id
    # Get a specific organization by permalink or ID
    def show
      organization = Organization[params[:id]]
      raise ActiveRecord::RecordNotFound, "Organization not found" unless organization

      render_success(
        organization: organization_to_hash(organization, include_details: true)
      )
    end

    # POST /management/api/v1/organizations
    # Create a new organization
    #
    # Required params:
    #   name - organization name
    #   owner_email - email of the user who will own this organization
    #
    # Optional params:
    #   permalink - custom permalink (auto-generated from name if not provided)
    #   time_zone - timezone (default: UTC)
    def create
      owner = User.find_by!(email_address: api_params[:owner_email])

      organization = Organization.create!(
        name: api_params[:name],
        permalink: api_params[:permalink],
        time_zone: api_params[:time_zone] || "UTC",
        owner: owner
      )

      # Add owner to organization
      organization.organization_users.create!(user: owner, admin: true, all_servers: true)

      render_success(
        organization: organization_to_hash(organization, include_details: true)
      )
    end

    # PATCH /management/api/v1/organizations/:id
    # Update an organization
    def update
      organization = Organization[params[:id]]
      raise ActiveRecord::RecordNotFound, "Organization not found" unless organization

      update_params = {}
      update_params[:name] = api_params[:name] if api_params[:name].present?
      update_params[:time_zone] = api_params[:time_zone] if api_params[:time_zone].present?

      organization.update!(update_params)

      render_success(organization: organization_to_hash(organization))
    end

    # DELETE /management/api/v1/organizations/:id
    # Delete an organization (soft delete)
    def destroy
      organization = Organization[params[:id]]
      raise ActiveRecord::RecordNotFound, "Organization not found" unless organization

      organization.soft_destroy
      render_success(message: "Organization '#{organization.name}' has been deleted")
    end

    # POST /management/api/v1/organizations/:id/suspend
    # Suspend an organization
    def suspend
      organization = Organization[params[:id]]
      raise ActiveRecord::RecordNotFound, "Organization not found" unless organization

      organization.update!(
        suspended_at: Time.now,
        suspension_reason: api_params[:reason] || "Suspended via Management API"
      )

      render_success(organization: organization_to_hash(organization))
    end

    # POST /management/api/v1/organizations/:id/unsuspend
    # Unsuspend an organization
    def unsuspend
      organization = Organization[params[:id]]
      raise ActiveRecord::RecordNotFound, "Organization not found" unless organization

      organization.update!(suspended_at: nil, suspension_reason: nil)

      render_success(organization: organization_to_hash(organization))
    end

    private

    def organization_to_hash(organization, include_details: false)
      hash = {
        id: organization.id,
        uuid: organization.uuid,
        name: organization.name,
        permalink: organization.permalink,
        time_zone: organization.time_zone,
        status: organization.status,
        suspended: organization.suspended?,
        suspended_at: organization.suspended_at,
        suspension_reason: organization.suspension_reason,
        owner: organization.owner ? {
          id: organization.owner.id,
          email: organization.owner.email_address,
          name: "#{organization.owner.first_name} #{organization.owner.last_name}"
        } : nil,
        servers_count: organization.servers.present.count,
        created_at: organization.created_at,
        updated_at: organization.updated_at
      }

      if include_details
        hash[:servers] = organization.servers.present.map do |s|
          {
            id: s.id,
            uuid: s.uuid,
            name: s.name,
            permalink: s.permalink,
            mode: s.mode,
            status: s.status
          }
        end
        hash[:ip_pools] = organization.ip_pools.map do |p|
          {
            id: p.id,
            name: p.name
          }
        end
      end

      hash
    end

  end
end
