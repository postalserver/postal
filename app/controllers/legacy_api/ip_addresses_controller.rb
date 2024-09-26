# frozen_string_literal: true

module LegacyAPI
  class IPAddressesController < BaseController

    # GET /api/v1/ip_pools/ip_addresses
    #
    # Parameters:
    #   ip_pool_id => REQ: The UUID of the IP pool
    #
    # Response:
    #   An array of IP addresses within the specified IP pool
    def index
      if params["ip_pool_id"].blank?
        render_parameter_error "`ip_pool_id` parameter is required but is missing"
        return
      end

      ip_pool = IPPool.find_by(id: params["ip_pool_id"])
      if ip_pool.nil?
        render_error "IPPoolNotFound",
                     message: "No IP pool found matching provided ID",
                     id: params["ip_pool_id"]
        return
      end

      ip_addresses = ip_pool.ip_addresses.map do |ip_address|
        {
          id: ip_address.id,
          ipv4: ip_address.ipv4,
          ipv6: ip_address.ipv6,
          hostname: ip_address.hostname,
          priority: ip_address.priority
        }
      end

      render_success ip_addresses: ip_addresses
    end

    # POST /api/v1/ip_pools/ip_addresses/create
    #
    # Parameters:
    #   ip_pool_id => REQ: The UUID of the IP pool
    #   ip_address => REQ: A hash of IP address attributes
    #
    # Response:
    #   The created IP address object
    def create
      if api_params["ip_pool_id"].blank? || api_params["ip_address"].blank?
        render_parameter_error "`ip_pool_id` and `ip_address` parameters are required but missing"
        return
      end

      ip_pool = IPPool.find_by_uuid(api_params["ip_pool_id"])
      if ip_pool.nil?
        render_error "IPPoolNotFound",
                     message: "No IP pool found matching provided ID",
                     id: api_params["ip_pool_id"]
        return
      end

      ip_address = ip_pool.ip_addresses.build(api_params["ip_address"])
      if ip_address.save
        render_success ip_address: ip_address.attributes, message: "IP Address created successfully"
      else
        render_error "ValidationError",
                     message: ip_address.errors.full_messages.to_sentence,
                     status: :unprocessable_entity
      end
    end

    # POST /api/v1/ip_pools/ip_addresses/update
    #
    # Parameters:
    #   ip_pool_id => REQ: The UUID of the IP pool
    #   id         => REQ: The ID of the IP address
    #   ip_address => REQ: A hash of IP address attributes to update
    #
    # Response:
    #   The updated IP address object
    def update
      if api_params["ip_pool_id"].blank? || api_params["id"].blank? || api_params["ip_address"].blank?
        render_parameter_error "`ip_pool_id`, `id`, and `ip_address` parameters are required but missing"
        return
      end

      ip_pool = IPPool.find_by_uuid(api_params["ip_pool_id"])
      if ip_pool.nil?
        render_error "IPPoolNotFound",
                     message: "No IP pool found matching provided ID",
                     id: api_params["ip_pool_id"]
        return
      end

      ip_address = ip_pool.ip_addresses.find_by(id: api_params["id"])
      if ip_address.nil?
        render_error "IPAddressNotFound",
                     message: "No IP address found matching provided ID",
                     id: api_params["id"]
        return
      end

      if ip_address.update(api_params["ip_address"])
        render_success ip_address: ip_address.attributes, message: "IP Address updated successfully"
      else
        render_error "ValidationError",
                     message: ip_address.errors.full_messages.to_sentence,
                     status: :unprocessable_entity
      end
    end

    # POST /api/v1/ip_pools/ip_addresses/delete
    #
    # Parameters:
    #   ip_pool_id => REQ: The UUID of the IP pool
    #   id         => REQ: The ID of the IP address to delete
    #
    # Response:
    #   Success message upon deletion
    def delete
      if api_params["ip_pool_id"].blank? || api_params["id"].blank?
        render_parameter_error "`ip_pool_id` and `id` parameters are required but missing"
        return
      end

      ip_pool = IPPool.find_by_uuid(api_params["ip_pool_id"])
      if ip_pool.nil?
        render_error "IPPoolNotFound",
                     message: "No IP pool found matching provided ID",
                     id: api_params["ip_pool_id"]
        return
      end

      ip_address = ip_pool.ip_addresses.find_by(id: api_params["id"])
      if ip_address.nil?
        render_error "IPAddressNotFound",
                     message: "No IP address found matching provided ID",
                     id: api_params["id"]
        return
      end

      if ip_address.destroy
        render_success message: "IP Address deleted successfully"
      else
        render_error "DeleteError",
                     message: "Failed to delete IP Address",
                     status: :unprocessable_entity
      end
    end

  end
end
