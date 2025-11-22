# frozen_string_literal: true

module ManagementAPI
  class OrganizationsController < BaseController

    before_action :set_organization, only: [:show, :update, :destroy, :suspend, :unsuspend]

    # GET /api/v2/management/organizations
    def index
      authorize!(:organizations, :read)

      scope = current_api_key.accessible_organizations.order(created_at: :desc)

      # Filtering
      scope = scope.where("name LIKE ?", "%#{api_params[:name]}%") if api_params[:name].present?
      scope = scope.where(permalink: api_params[:permalink]) if api_params[:permalink].present?

      result = paginate(scope)
      render_success(result[:records].map { |o| serialize_organization(o) }, meta: result[:meta])
    end

    # GET /api/v2/management/organizations/:id
    def show
      authorize!(:organizations, :read)
      render_success(serialize_organization(@organization, detailed: true))
    end

    # POST /api/v2/management/organizations
    def create
      authorize!(:organizations, :write)

      # Find or require owner
      owner = find_owner
      return if performed?

      organization = Organization.new(organization_params)
      organization.owner = owner

      if organization.save
        render_created(serialize_organization(organization))
      else
        render json: {
          status: "error",
          time: elapsed_time,
          error: {
            code: "ValidationError",
            message: "Failed to create organization",
            details: organization.errors.to_hash
          }
        }, status: :unprocessable_entity
      end
    end

    # PATCH /api/v2/management/organizations/:id
    def update
      authorize!(:organizations, :write)

      if @organization.update(organization_params)
        render_success(serialize_organization(@organization))
      else
        render json: {
          status: "error",
          time: elapsed_time,
          error: {
            code: "ValidationError",
            message: "Failed to update organization",
            details: @organization.errors.to_hash
          }
        }, status: :unprocessable_entity
      end
    end

    # DELETE /api/v2/management/organizations/:id
    def destroy
      authorize!(:organizations, :delete)

      @organization.soft_destroy
      render_deleted
    end

    # POST /api/v2/management/organizations/:id/suspend
    def suspend
      authorize!(:organizations, :write)

      reason = api_params[:reason] || "Suspended via Management API"
      @organization.update!(suspended_at: Time.current, suspension_reason: reason)

      render_success(serialize_organization(@organization))
    end

    # POST /api/v2/management/organizations/:id/unsuspend
    def unsuspend
      authorize!(:organizations, :write)

      @organization.update!(suspended_at: nil, suspension_reason: nil)
      render_success(serialize_organization(@organization))
    end

    private

    def set_organization
      @organization = current_api_key.accessible_organizations.find_by!(permalink: params[:id]) ||
                      current_api_key.accessible_organizations.find_by!(uuid: params[:id])
    rescue ActiveRecord::RecordNotFound
      # Try by uuid if permalink not found
      @organization = current_api_key.accessible_organizations.find_by!(uuid: params[:id])
    end

    def organization_params
      {
        name: api_params[:name],
        permalink: api_params[:permalink],
        time_zone: api_params[:time_zone]
      }.compact
    end

    def find_owner
      if api_params[:owner_email].present?
        owner = User.find_by(email_address: api_params[:owner_email])
        if owner.nil?
          render_error("OwnerNotFound", "User with email #{api_params[:owner_email]} not found", 404)
          return nil
        end
        owner
      elsif api_params[:owner_uuid].present?
        owner = User.find_by(uuid: api_params[:owner_uuid])
        if owner.nil?
          render_error("OwnerNotFound", "User with UUID #{api_params[:owner_uuid]} not found", 404)
          return nil
        end
        owner
      else
        render_error("OwnerRequired", "owner_email or owner_uuid is required", 400)
        nil
      end
    end

    def serialize_organization(org, detailed: false)
      data = {
        uuid: org.uuid,
        name: org.name,
        permalink: org.permalink,
        time_zone: org.time_zone,
        status: org.status,
        suspended: org.suspended?,
        created_at: org.created_at&.iso8601,
        updated_at: org.updated_at&.iso8601
      }

      if detailed
        data.merge!(
          owner: org.owner ? { uuid: org.owner.uuid, email: org.owner.email_address, name: org.owner.name } : nil,
          servers_count: org.servers.count,
          domains_count: org.domains.count,
          users_count: org.users.count,
          suspension_reason: org.suspension_reason
        )
      end

      data
    end

  end
end
