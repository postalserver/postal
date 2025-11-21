# frozen_string_literal: true

module ManagementAPI
  class IpPoolsController < BaseController

    # GET /management/api/v1/ip_pools
    # Returns all available IP pools with their IP addresses
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "ip_pools": [
    #       {
    #         "id": 1,
    #         "uuid": "xxx",
    #         "name": "Default Pool",
    #         "default": true,
    #         "ip_addresses": [
    #           { "id": 1, "ip_address": "45.12.138.7", "hostname": "mail1.example.com" }
    #         ]
    #       }
    #     ]
    #   }
    # }
    def index
      ip_pools = IPPool.includes(:ip_addresses).all

      render_success(
        ip_pools: ip_pools.map do |pool|
          {
            id: pool.id,
            uuid: pool.uuid,
            name: pool.name,
            default: pool.default?,
            ip_addresses: pool.ip_addresses.map do |ip|
              {
                id: ip.id,
                ip_address: ip.ipv4.presence || ip.ipv6,
                ipv4: ip.ipv4,
                ipv6: ip.ipv6,
                hostname: ip.hostname
              }
            end
          }
        end
      )
    end

    # GET /management/api/v1/ip_pools/:id
    # Returns a specific IP pool with its IP addresses
    def show
      pool = IPPool.includes(:ip_addresses).find(params[:id])

      render_success(
        ip_pool: {
          id: pool.id,
          uuid: pool.uuid,
          name: pool.name,
          default: pool.default?,
          ip_addresses: pool.ip_addresses.map do |ip|
            {
              id: ip.id,
              ip_address: ip.ipv4.presence || ip.ipv6,
              ipv4: ip.ipv4,
              ipv6: ip.ipv6,
              hostname: ip.hostname
            }
          end
        }
      )
    end

    # GET /management/api/v1/organizations/:org/ip_pools
    # Returns IP pools available for a specific organization
    def for_organization
      organization = find_organization(api_params[:org])
      pools = organization.ip_pools.includes(:ip_addresses)

      render_success(
        organization: organization.permalink,
        ip_pools: pools.map do |pool|
          {
            id: pool.id,
            uuid: pool.uuid,
            name: pool.name,
            default: pool.default?,
            ip_addresses: pool.ip_addresses.map do |ip|
              {
                id: ip.id,
                ip_address: ip.ipv4.presence || ip.ipv6,
                ipv4: ip.ipv4,
                ipv6: ip.ipv6,
                hostname: ip.hostname
              }
            end
          }
        end
      )
    end

  end
end
