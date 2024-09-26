# frozen_string_literal: true

module LegacyAPI
  class OrganizationIPPoolsController < BaseController

    # GET /api/v1/organizations/ip_pools
    #
    # Parameters:
    #   organization_id => REQ: The UUID of the organization
    #
    # Response:
    #   An array of IP pools assigned to the organization
    def index
      if api_params["organization_id"].blank?
        render_parameter_error "`organization_id` parameter is required but missing"
        return
      end

      organization = Organization.find_by_uuid(api_params["organization_id"])
      if organization.nil?
        render_error "OrganizationNotFound",
                     message: "No organization found matching provided ID",
                     id: api_params["organization_id"]
        return
      end

      ip_pools = organization.ip_pools.order(:name).map do |ip_pool|
        {
          id: ip_pool.id,
          name: ip_pool.name,
          default: ip_pool.default
        }
      end

      render_success ip_pools: ip_pools
    end

    # POST /api/v1/organizations/ip_pools/assignments
    #
    # Parameters:
    #   organization_id => REQ: The UUID of the organization
    #   ip_pools        => REQ: An array of IP pool IDs to assign
    #
    # Response:
    #   Success message upon updating assignments
    def assignments
      if api_params["organization_id"].blank? || api_params["ip_pools"].blank?
        render_parameter_error "`organization_id` and `ip_pools` parameters are required but missing"
        return
      end

      organization = Organization.find_by_uuid(api_params["organization_id"])
      if organization.nil?
        render_error "OrganizationNotFound",
                     message: "No organization found matching provided ID",
                     id: api_params["organization_id"]
        return
      end

      organization.ip_pool_ids = api_params["ip_pools"]
      if organization.save
        render_success message: "Organization IP pools have been updated successfully"
      else
        render_error "UpdateError",
                     message: organization.errors.full_messages.to_sentence,
                     status: :unprocessable_entity
      end
    end

  end
end
