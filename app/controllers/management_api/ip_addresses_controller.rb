# frozen_string_literal: true

module ManagementAPI
  class IPAddressesController < BaseController

    # GET /management/api/v1/ip_pools/:ip_pool_id/ip_addresses
    # List all IP addresses in a pool
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "ip_addresses": [
    #       { "id": 1, "ipv4": "192.168.1.1", "ipv6": "::1", "hostname": "mail.example.com", "priority": 100 }
    #     ]
    #   }
    # }
    def index
      ip_pool = IPPool.find(params[:ip_pool_id])

      render_success(
        ip_pool: {
          id: ip_pool.id,
          name: ip_pool.name
        },
        ip_addresses: ip_pool.ip_addresses.order_by_priority.map { |ip| ip_address_to_hash(ip) }
      )
    end

    # GET /management/api/v1/ip_pools/:ip_pool_id/ip_addresses/:id
    # Get a specific IP address
    def show
      ip_pool = IPPool.find(params[:ip_pool_id])
      ip_address = ip_pool.ip_addresses.find(params[:id])

      render_success(ip_address: ip_address_to_hash(ip_address))
    end

    # POST /management/api/v1/ip_pools/:ip_pool_id/ip_addresses
    # Create a new IP address in a pool
    #
    # Required params:
    #   ipv4 - IPv4 address
    #   hostname - hostname for the IP address
    #
    # Optional params:
    #   ipv6 - IPv6 address
    #   priority - priority (0-100, default: 100)
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "ip_address": { ... }
    #   }
    # }
    def create
      ip_pool = IPPool.find(params[:ip_pool_id])

      ip_address = ip_pool.ip_addresses.create!(
        ipv4: api_params[:ipv4],
        ipv6: api_params[:ipv6],
        hostname: api_params[:hostname],
        priority: api_params[:priority] || 100
      )

      render_success(ip_address: ip_address_to_hash(ip_address))
    end

    # PATCH /management/api/v1/ip_pools/:ip_pool_id/ip_addresses/:id
    # Update an IP address
    #
    # Params:
    #   ipv4 - IPv4 address
    #   ipv6 - IPv6 address
    #   hostname - hostname
    #   priority - priority (0-100)
    def update
      ip_pool = IPPool.find(params[:ip_pool_id])
      ip_address = ip_pool.ip_addresses.find(params[:id])

      update_params = {}
      update_params[:ipv4] = api_params[:ipv4] if api_params[:ipv4].present?
      update_params[:ipv6] = api_params[:ipv6] if api_params.key?(:ipv6)
      update_params[:hostname] = api_params[:hostname] if api_params[:hostname].present?
      update_params[:priority] = api_params[:priority] if api_params[:priority].present?

      ip_address.update!(update_params)

      render_success(ip_address: ip_address_to_hash(ip_address))
    end

    # DELETE /management/api/v1/ip_pools/:ip_pool_id/ip_addresses/:id
    # Delete an IP address
    def destroy
      ip_pool = IPPool.find(params[:ip_pool_id])
      ip_address = ip_pool.ip_addresses.find(params[:id])

      ip_address.destroy!
      render_success(message: "IP address '#{ip_address.ipv4}' has been deleted")
    end

    private

    def ip_address_to_hash(ip_address)
      {
        id: ip_address.id,
        ipv4: ip_address.ipv4,
        ipv6: ip_address.ipv6,
        hostname: ip_address.hostname,
        priority: ip_address.priority,
        created_at: ip_address.created_at,
        updated_at: ip_address.updated_at
      }
    end

  end
end
