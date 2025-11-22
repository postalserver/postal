# frozen_string_literal: true

module ManagementAPI
  class SMTPEndpointsController < BaseController

    # GET /management/api/v1/servers/:server_id/smtp_endpoints
    # List all SMTP endpoints for a server
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "smtp_endpoints": [
    #       { "uuid": "xxx", "name": "External SMTP", "hostname": "smtp.example.com", ... }
    #     ]
    #   }
    # }
    def index
      server = find_server(params[:server_id])
      endpoints = server.smtp_endpoints

      render_success(
        smtp_endpoints: endpoints.map { |e| smtp_endpoint_to_hash(e) }
      )
    end

    # GET /management/api/v1/servers/:server_id/smtp_endpoints/:uuid
    # Get a specific SMTP endpoint
    def show
      server = find_server(params[:server_id])
      endpoint = server.smtp_endpoints.find_by!(uuid: params[:id])

      render_success(smtp_endpoint: smtp_endpoint_to_hash(endpoint, include_routes: true))
    end

    # POST /management/api/v1/servers/:server_id/smtp_endpoints
    # Create a new SMTP endpoint
    #
    # Required params:
    #   name - endpoint name
    #   hostname - SMTP server hostname
    #
    # Optional params:
    #   port - SMTP port (default: 25)
    #   ssl_mode - "None", "Auto", "STARTTLS", "TLS" (default: "Auto")
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "smtp_endpoint": { ... }
    #   }
    # }
    def create
      server = find_server(params[:server_id])

      endpoint = server.smtp_endpoints.create!(
        name: api_params[:name],
        hostname: api_params[:hostname],
        port: api_params[:port] || 25,
        ssl_mode: api_params[:ssl_mode] || "Auto"
      )

      render_success(smtp_endpoint: smtp_endpoint_to_hash(endpoint))
    end

    # PATCH /management/api/v1/servers/:server_id/smtp_endpoints/:uuid
    # Update an SMTP endpoint
    #
    # Params:
    #   name - endpoint name
    #   hostname - SMTP server hostname
    #   port - SMTP port
    #   ssl_mode - SSL mode
    def update
      server = find_server(params[:server_id])
      endpoint = server.smtp_endpoints.find_by!(uuid: params[:id])

      update_params = {}
      update_params[:name] = api_params[:name] if api_params[:name].present?
      update_params[:hostname] = api_params[:hostname] if api_params[:hostname].present?
      update_params[:port] = api_params[:port] if api_params[:port].present?
      update_params[:ssl_mode] = api_params[:ssl_mode] if api_params[:ssl_mode].present?

      endpoint.update!(update_params)

      render_success(smtp_endpoint: smtp_endpoint_to_hash(endpoint))
    end

    # DELETE /management/api/v1/servers/:server_id/smtp_endpoints/:uuid
    # Delete an SMTP endpoint
    def destroy
      server = find_server(params[:server_id])
      endpoint = server.smtp_endpoints.find_by!(uuid: params[:id])

      # Check if endpoint is used by routes
      if endpoint.routes.any?
        render_error "InUse", message: "Endpoint is used by #{endpoint.routes.count} route(s). Routes will be set to Reject mode."
      end

      endpoint.destroy!
      render_success(message: "SMTP endpoint '#{endpoint.name}' has been deleted")
    end

    private

    def smtp_endpoint_to_hash(endpoint, include_routes: false)
      hash = {
        uuid: endpoint.uuid,
        name: endpoint.name,
        hostname: endpoint.hostname,
        port: endpoint.port,
        ssl_mode: endpoint.ssl_mode,
        last_used_at: endpoint.last_used_at,
        error: endpoint.error,
        disabled_until: endpoint.disabled_until,
        created_at: endpoint.created_at,
        updated_at: endpoint.updated_at
      }

      if include_routes
        hash[:routes] = endpoint.routes.map do |r|
          {
            uuid: r.uuid,
            description: r.description
          }
        end
      end

      hash
    end

  end
end
