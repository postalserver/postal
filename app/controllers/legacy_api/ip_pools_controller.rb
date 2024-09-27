# frozen_string_literal: true

module LegacyAPI
  class IPPoolsController < BaseController

    # GET /api/v1/ip_pools
    #
    # Response:
    #   An array of all IP pools
    def index
      ip_pools = IPPool.order(:name).map do |ip_pool|
        {
          id: ip_pool.id,
          name: ip_pool.name,
          default: ip_pool.default,
        }
      end

      render_success ip_pools: ip_pools
    end

    # POST /api/v1/ip_pools/create
    #
    # Parameters:
    #   ip_pool => REQ: A hash of IP pool attributes
    #
    # Response:
    #   The created IP pool object
    def create
      if api_params["ip_pool"].blank?
        render_parameter_error "`ip_pool` parameter is required but missing"
        return
      end

      ip_pool = IPPool.new(api_params["ip_pool"])
      if ip_pool.save
        render_success ip_pool: ip_pool.attributes, message: "IP Pool created successfully"
      else
        render_error "ValidationError",
                     message: ip_pool.errors.full_messages.to_sentence,
                     status: :unprocessable_entity
      end
    end

    # POST /api/v1/ip_pools/update
    #
    # Parameters:
    #   id      => REQ: The ID of the IP pool to update
    #   ip_pool => REQ: A hash of IP pool attributes to update
    #
    # Response:
    #   The updated IP pool object
    def update
      if api_params["id"].blank? || api_params["ip_pool"].blank?
        render_parameter_error "`id` and `ip_pool` parameters are required but missing"
        return
      end

      ip_pool = IPPool.find_by(id: api_params["id"])
      if ip_pool.nil?
        render_error "IPPoolNotFound",
                     message: "No IP pool found matching provided ID",
                     id: api_params["id"]
        return
      end

      if ip_pool.update(api_params["ip_pool"])
        render_success ip_pool: ip_pool.attributes, message: "IP Pool updated successfully"
      else
        render_error "ValidationError",
                     message: ip_pool.errors.full_messages.to_sentence,
                     status: :unprocessable_entity
      end
    end

    # POST /api/v1/ip_pools/delete
    #
    # Parameters:
    #   id => REQ: The ID of the IP pool to delete
    #
    # Response:
    #   Success message upon deletion
    def delete
      if params["id"].blank?
        render_parameter_error "`id` parameter is required but missing"
        return
      end

      ip_pool = IPPool.find_by(id: params["id"])
      if ip_pool.nil?
        render_error "IPPoolNotFound",
                     message: "No IP pool found matching provided ID",
                     id: params["id"]
        return
      end

      if ip_pool.destroy
        render_success message: "IP Pool deleted successfully"
      else
        render_error "DeleteError",
                     message: "IP Pool cannot be removed because it still has associated addresses or servers",
                     status: :unprocessable_entity
      end
    rescue ActiveRecord::DeleteRestrictionError
      render_error "DeleteRestrictionError",
                   message: "IP Pool cannot be removed because it still has associated addresses or servers",
                   status: :unprocessable_entity
    end
  end
end
