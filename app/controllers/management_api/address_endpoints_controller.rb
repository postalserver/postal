# frozen_string_literal: true

module ManagementAPI
  class AddressEndpointsController < BaseController

    # GET /management/api/v1/servers/:server_id/address_endpoints
    # List all address endpoints for a server
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "address_endpoints": [
    #       { "uuid": "xxx", "address": "forward@example.com", ... }
    #     ]
    #   }
    # }
    def index
      server = find_server(params[:server_id])
      endpoints = server.address_endpoints

      render_success(
        address_endpoints: endpoints.map { |e| address_endpoint_to_hash(e) }
      )
    end

    # GET /management/api/v1/servers/:server_id/address_endpoints/:uuid
    # Get a specific address endpoint
    def show
      server = find_server(params[:server_id])
      endpoint = server.address_endpoints.find_by!(uuid: params[:id])

      render_success(address_endpoint: address_endpoint_to_hash(endpoint, include_routes: true))
    end

    # POST /management/api/v1/servers/:server_id/address_endpoints
    # Create a new address endpoint
    #
    # Required params:
    #   address - email address to forward to
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "address_endpoint": { ... }
    #   }
    # }
    def create
      server = find_server(params[:server_id])

      endpoint = server.address_endpoints.create!(
        address: api_params[:address]
      )

      render_success(address_endpoint: address_endpoint_to_hash(endpoint))
    end

    # PATCH /management/api/v1/servers/:server_id/address_endpoints/:uuid
    # Update an address endpoint
    #
    # Params:
    #   address - email address to forward to
    def update
      server = find_server(params[:server_id])
      endpoint = server.address_endpoints.find_by!(uuid: params[:id])

      update_params = {}
      update_params[:address] = api_params[:address] if api_params[:address].present?

      endpoint.update!(update_params)

      render_success(address_endpoint: address_endpoint_to_hash(endpoint))
    end

    # DELETE /management/api/v1/servers/:server_id/address_endpoints/:uuid
    # Delete an address endpoint
    def destroy
      server = find_server(params[:server_id])
      endpoint = server.address_endpoints.find_by!(uuid: params[:id])

      # Check if endpoint is used by routes
      if endpoint.routes.any?
        render_error "InUse", message: "Endpoint is used by #{endpoint.routes.count} route(s). Routes will be set to Reject mode."
      end

      endpoint.destroy!
      render_success(message: "Address endpoint '#{endpoint.address}' has been deleted")
    end

    private

    def address_endpoint_to_hash(endpoint, include_routes: false)
      hash = {
        uuid: endpoint.uuid,
        address: endpoint.address,
        domain: endpoint.domain,
        last_used_at: endpoint.last_used_at,
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
