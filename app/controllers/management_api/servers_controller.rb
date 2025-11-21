# frozen_string_literal: true

module ManagementAPI
  class ServersController < BaseController

    # GET /management/api/v1/servers
    # List all servers (optionally filtered by organization)
    #
    # Params:
    #   organization (optional) - filter by organization permalink
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "servers": [
    #       { "id": 1, "uuid": "xxx", "name": "Server1", "permalink": "server1", ... }
    #     ]
    #   }
    # }
    def index
      servers = Server.present.includes(:organization, :ip_pool)

      if api_params[:organization].present?
        org = find_organization(api_params[:organization])
        servers = servers.where(organization: org)
      end

      render_success(
        servers: servers.map { |s| server_to_hash(s) }
      )
    end

    # GET /management/api/v1/servers/:id
    # Get a specific server by ID or permalink (org/server format)
    def show
      server = find_server(params[:id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      render_success(server: server_to_hash(server, include_stats: true))
    end

    # POST /management/api/v1/servers
    # Create a new server
    #
    # Required params:
    #   organization - organization permalink
    #   name - server name
    #
    # Optional params:
    #   mode - "Live" or "Development" (default: "Live")
    #   ip_pool_id - ID of IP pool to use
    #   permalink - custom permalink (auto-generated from name if not provided)
    #   message_retention_days - days to keep messages (default: 60)
    #   raw_message_retention_days - days to keep raw messages (default: 30)
    #   raw_message_retention_size - max size in MB for raw messages (default: 2048)
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "server": { ... },
    #     "credentials": { "api_key": "...", "smtp_key": "..." }
    #   }
    # }
    def create
      organization = find_organization(api_params[:organization])

      # Find IP pool if specified
      ip_pool = nil
      if api_params[:ip_pool_id].present?
        ip_pool = organization.ip_pools.find(api_params[:ip_pool_id])
      end

      server = organization.servers.create!(
        name: api_params[:name],
        mode: api_params[:mode] || "Live",
        ip_pool: ip_pool,
        permalink: api_params[:permalink],
        message_retention_days: api_params[:message_retention_days] || 2,
        raw_message_retention_days: api_params[:raw_message_retention_days] || 2,
        raw_message_retention_size: api_params[:raw_message_retention_size] || 12048
      )

      # Create API credential automatically
      api_credential = server.credentials.create!(
        name: "API",
        type: "API"
      )

      render_success(
        server: server_to_hash(server),
        credentials: {
          api_key: api_credential.key,
          api_credential_uuid: api_credential.uuid
        }
      )
    end

    # PATCH /management/api/v1/servers/:id
    # Update server settings
    #
    # Params:
    #   name - server name
    #   mode - "Live" or "Development"
    #   ip_pool_id - ID of IP pool
    #   message_retention_days - days to keep messages
    #   raw_message_retention_days - days to keep raw messages
    #   raw_message_retention_size - max size in MB for raw messages
    def update
      server = find_server(params[:id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      update_params = {}

      # Basic settings
      update_params[:name] = api_params[:name] if api_params[:name].present?
      update_params[:mode] = api_params[:mode] if api_params[:mode].present?

      # Retention settings
      if api_params[:message_retention_days].present?
        update_params[:message_retention_days] = api_params[:message_retention_days].to_i
      end
      if api_params[:raw_message_retention_days].present?
        update_params[:raw_message_retention_days] = api_params[:raw_message_retention_days].to_i
      end
      if api_params[:raw_message_retention_size].present?
        update_params[:raw_message_retention_size] = api_params[:raw_message_retention_size].to_i
      end

      # IP pool
      if api_params.key?(:ip_pool_id)
        if api_params[:ip_pool_id].present?
          update_params[:ip_pool] = server.organization.ip_pools.find(api_params[:ip_pool_id])
        else
          update_params[:ip_pool] = nil
        end
      end

      server.update!(update_params)

      render_success(server: server_to_hash(server))
    end

    # DELETE /management/api/v1/servers/:id
    # Delete a server
    def destroy
      server = find_server(params[:id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      server.soft_destroy
      render_success(message: "Server '#{server.name}' has been deleted")
    end

    # POST /management/api/v1/servers/:id/suspend
    # Suspend a server
    def suspend
      server = find_server(params[:id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      server.suspend(api_params[:reason] || "Suspended via Management API")
      render_success(server: server_to_hash(server))
    end

    # POST /management/api/v1/servers/:id/unsuspend
    # Unsuspend a server
    def unsuspend
      server = find_server(params[:id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      server.unsuspend
      render_success(server: server_to_hash(server))
    end

    private

    def server_to_hash(server, include_stats: false)
      hash = {
        id: server.id,
        uuid: server.uuid,
        name: server.name,
        permalink: server.permalink,
        full_permalink: server.full_permalink,
        mode: server.mode,
        status: server.status,
        token: server.token,
        organization: server.organization.permalink,
        ip_pool: server.ip_pool ? {
          id: server.ip_pool.id,
          name: server.ip_pool.name
        } : nil,
        message_retention_days: server.message_retention_days,
        raw_message_retention_days: server.raw_message_retention_days,
        raw_message_retention_size: server.raw_message_retention_size,
        suspended: server.suspended?,
        suspended_at: server.suspended_at,
        suspension_reason: server.suspension_reason,
        created_at: server.created_at,
        updated_at: server.updated_at
      }

      if include_stats
        hash[:domains_count] = server.domains.count
        hash[:credentials_count] = server.credentials.count
        hash[:webhooks_count] = server.webhooks.count
      end

      hash
    end

  end
end
