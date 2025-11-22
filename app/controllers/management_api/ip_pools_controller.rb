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
    #         "ip_addresses": [...]
    #       }
    #     ]
    #   }
    # }
    def index
      ip_pools = IPPool.includes(:ip_addresses).all

      render_success(
        ip_pools: ip_pools.map { |pool| ip_pool_to_hash(pool) }
      )
    end

    # GET /management/api/v1/ip_pools/:id
    # Returns a specific IP pool with its IP addresses
    def show
      pool = IPPool.includes(:ip_addresses).find(params[:id])

      render_success(ip_pool: ip_pool_to_hash(pool, include_organizations: true))
    end

    # POST /management/api/v1/ip_pools
    # Create a new IP pool
    #
    # Required params:
    #   name - pool name
    #
    # Optional params:
    #   default - make this the default pool (default: false)
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "ip_pool": { ... }
    #   }
    # }
    def create
      pool = IPPool.create!(
        name: api_params[:name],
        default: api_params[:default] == true || api_params[:default] == "true"
      )

      render_success(ip_pool: ip_pool_to_hash(pool))
    end

    # PATCH /management/api/v1/ip_pools/:id
    # Update an IP pool
    #
    # Params:
    #   name - pool name
    #   default - make this the default pool
    def update
      pool = IPPool.find(params[:id])

      update_params = {}
      update_params[:name] = api_params[:name] if api_params[:name].present?
      if api_params.key?(:default)
        update_params[:default] = api_params[:default] == true || api_params[:default] == "true"
      end

      pool.update!(update_params)

      render_success(ip_pool: ip_pool_to_hash(pool))
    end

    # DELETE /management/api/v1/ip_pools/:id
    # Delete an IP pool
    def destroy
      pool = IPPool.find(params[:id])

      if pool.default?
        render_error "CannotDeleteDefault", message: "Cannot delete the default IP pool"
        return
      end

      if pool.servers.any?
        render_error "InUse", message: "IP pool is assigned to #{pool.servers.count} server(s)"
        return
      end

      pool.destroy!
      render_success(message: "IP pool '#{pool.name}' has been deleted")
    end

    # GET /management/api/v1/organizations/:org/ip_pools
    # Returns IP pools available for a specific organization
    def for_organization
      organization = find_organization(params[:organization_id])
      pools = organization.ip_pools.includes(:ip_addresses)

      render_success(
        organization: organization.permalink,
        ip_pools: pools.map { |pool| ip_pool_to_hash(pool) }
      )
    end

    # POST /management/api/v1/organizations/:org/ip_pools/assign
    # Assign IP pools to an organization
    #
    # Params:
    #   ip_pool_ids - array of IP pool IDs to assign
    def assign_to_organization
      organization = find_organization(params[:organization_id])
      ip_pool_ids = api_params[:ip_pool_ids]

      unless ip_pool_ids.is_a?(Array)
        render_error "InvalidParameter", message: "ip_pool_ids must be an array"
        return
      end

      # Clear existing assignments
      organization.organization_ip_pools.destroy_all

      # Create new assignments
      ip_pool_ids.each do |pool_id|
        pool = IPPool.find(pool_id)
        organization.organization_ip_pools.create!(ip_pool: pool)
      end

      render_success(
        message: "IP pools assigned to organization",
        organization: organization.permalink,
        ip_pools: organization.ip_pools.reload.map { |pool| ip_pool_to_hash(pool) }
      )
    end

    private

    def ip_pool_to_hash(pool, include_organizations: false)
      hash = {
        id: pool.id,
        uuid: pool.uuid,
        name: pool.name,
        default: pool.default?,
        ip_addresses: pool.ip_addresses.order_by_priority.map do |ip|
          {
            id: ip.id,
            ipv4: ip.ipv4,
            ipv6: ip.ipv6,
            hostname: ip.hostname,
            priority: ip.priority
          }
        end,
        servers_count: pool.servers.count,
        created_at: pool.created_at,
        updated_at: pool.updated_at
      }

      if include_organizations
        hash[:organizations] = pool.organizations.map do |org|
          {
            permalink: org.permalink,
            name: org.name
          }
        end
      end

      hash
    end

  end
end
