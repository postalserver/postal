# frozen_string_literal: true

module ManagementAPI
  class RoutesController < BaseController

    # GET /management/api/v1/servers/:server_id/routes
    # List all routes for a server
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "routes": [
    #       { "uuid": "xxx", "name": "*", "domain": "example.com", "mode": "Endpoint", ... }
    #     ]
    #   }
    # }
    def index
      server = find_server(params[:server_id])
      routes = server.routes.includes(:domain, :endpoint)

      render_success(
        routes: routes.map { |r| route_to_hash(r) }
      )
    end

    # GET /management/api/v1/servers/:server_id/routes/:uuid
    # Get a specific route
    def show
      server = find_server(params[:server_id])
      route = server.routes.find_by!(uuid: params[:id])

      render_success(route: route_to_hash(route, include_details: true))
    end

    # POST /management/api/v1/servers/:server_id/routes
    # Create a new route
    #
    # Required params:
    #   name - route name (e.g., "*" for wildcard, "support" for support@domain.com)
    #   domain_uuid - UUID of the domain (not required for return path routes)
    #
    # Optional params:
    #   mode - "Endpoint", "Accept", "Hold", "Bounce", "Reject" (default: determined by endpoint)
    #   endpoint_type - "HTTPEndpoint", "SMTPEndpoint", "AddressEndpoint"
    #   endpoint_uuid - UUID of the endpoint
    #   spam_mode - "Mark", "Quarantine", "Fail" (default: "Mark")
    #   additional_endpoints - array of { endpoint_type, endpoint_uuid }
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "route": { ... }
    #   }
    # }
    def create
      server = find_server(params[:server_id])

      route_params = {
        name: api_params[:name],
        spam_mode: api_params[:spam_mode] || "Mark"
      }

      # Handle domain
      if api_params[:domain_uuid].present?
        domain = find_domain_for_server(server, api_params[:domain_uuid])
        route_params[:domain] = domain
      end

      # Handle endpoint
      if api_params[:endpoint_uuid].present? && api_params[:endpoint_type].present?
        endpoint = find_endpoint(server, api_params[:endpoint_type], api_params[:endpoint_uuid])
        route_params[:endpoint] = endpoint
        route_params[:mode] = "Endpoint"
      elsif api_params[:mode].present?
        route_params[:mode] = api_params[:mode]
      end

      route = server.routes.create!(route_params)

      # Handle additional endpoints
      if api_params[:additional_endpoints].is_a?(Array)
        additional = api_params[:additional_endpoints].map do |ep|
          "#{ep[:endpoint_type]}##{ep[:endpoint_uuid]}"
        end
        route.additional_route_endpoints_array = additional
        route.save!
      end

      render_success(route: route_to_hash(route.reload, include_details: true))
    end

    # PATCH /management/api/v1/servers/:server_id/routes/:uuid
    # Update a route
    #
    # Params:
    #   name - route name
    #   domain_uuid - UUID of the domain
    #   mode - route mode
    #   endpoint_type - endpoint type
    #   endpoint_uuid - endpoint UUID
    #   spam_mode - spam handling mode
    #   additional_endpoints - array of { endpoint_type, endpoint_uuid }
    def update
      server = find_server(params[:server_id])
      route = server.routes.find_by!(uuid: params[:id])

      update_params = {}
      update_params[:name] = api_params[:name] if api_params[:name].present?
      update_params[:spam_mode] = api_params[:spam_mode] if api_params[:spam_mode].present?

      # Handle domain change
      if api_params.key?(:domain_uuid)
        if api_params[:domain_uuid].present?
          domain = find_domain_for_server(server, api_params[:domain_uuid])
          update_params[:domain] = domain
        else
          update_params[:domain] = nil
        end
      end

      # Handle endpoint change
      if api_params[:endpoint_uuid].present? && api_params[:endpoint_type].present?
        endpoint = find_endpoint(server, api_params[:endpoint_type], api_params[:endpoint_uuid])
        update_params[:endpoint] = endpoint
        update_params[:mode] = "Endpoint"
      elsif api_params[:mode].present?
        update_params[:mode] = api_params[:mode]
        update_params[:endpoint] = nil unless api_params[:mode] == "Endpoint"
      end

      route.update!(update_params)

      # Handle additional endpoints
      if api_params.key?(:additional_endpoints)
        if api_params[:additional_endpoints].is_a?(Array)
          additional = api_params[:additional_endpoints].map do |ep|
            "#{ep[:endpoint_type]}##{ep[:endpoint_uuid]}"
          end
          route.additional_route_endpoints_array = additional
        else
          route.additional_route_endpoints_array = []
        end
        route.save!
      end

      render_success(route: route_to_hash(route.reload, include_details: true))
    end

    # DELETE /management/api/v1/servers/:server_id/routes/:uuid
    # Delete a route
    def destroy
      server = find_server(params[:server_id])
      route = server.routes.find_by!(uuid: params[:id])

      route.destroy!
      render_success(message: "Route '#{route.description}' has been deleted")
    end

    private

    def find_domain_for_server(server, uuid)
      # Try server domains first, then organization domains
      domain = server.domains.find_by(uuid: uuid)
      domain ||= server.organization.domains.find_by!(uuid: uuid)
      domain
    end

    def find_endpoint(server, type, uuid)
      case type
      when "HTTPEndpoint"
        server.http_endpoints.find_by!(uuid: uuid)
      when "SMTPEndpoint"
        server.smtp_endpoints.find_by!(uuid: uuid)
      when "AddressEndpoint"
        server.address_endpoints.find_by!(uuid: uuid)
      else
        raise ActiveRecord::RecordNotFound, "Unknown endpoint type: #{type}"
      end
    end

    def route_to_hash(route, include_details: false)
      hash = {
        uuid: route.uuid,
        name: route.name,
        description: route.description,
        domain: route.domain ? {
          uuid: route.domain.uuid,
          name: route.domain.name
        } : nil,
        mode: route.mode,
        spam_mode: route.spam_mode,
        token: route.token,
        forward_address: route.forward_address,
        wildcard: route.wildcard?,
        return_path: route.return_path?,
        created_at: route.created_at,
        updated_at: route.updated_at
      }

      if route.mode == "Endpoint" && route.endpoint
        hash[:endpoint] = {
          type: route.endpoint_type,
          uuid: route.endpoint.uuid,
          description: route.endpoint.description
        }
      end

      if include_details && route.mode == "Endpoint"
        hash[:additional_endpoints] = route.additional_route_endpoints.map do |are|
          {
            type: are.endpoint_type,
            uuid: are.endpoint.uuid,
            description: are.endpoint.description
          }
        end
      end

      hash
    end

  end
end
