# frozen_string_literal: true

module ManagementAPI
  class HTTPEndpointsController < BaseController

    # GET /management/api/v1/servers/:server_id/http_endpoints
    # List all HTTP endpoints for a server
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "http_endpoints": [
    #       { "uuid": "xxx", "name": "Webhook", "url": "https://...", ... }
    #     ]
    #   }
    # }
    def index
      server = find_server(params[:server_id])
      endpoints = server.http_endpoints

      render_success(
        http_endpoints: endpoints.map { |e| http_endpoint_to_hash(e) }
      )
    end

    # GET /management/api/v1/servers/:server_id/http_endpoints/:uuid
    # Get a specific HTTP endpoint
    def show
      server = find_server(params[:server_id])
      endpoint = server.http_endpoints.find_by!(uuid: params[:id])

      render_success(http_endpoint: http_endpoint_to_hash(endpoint, include_routes: true))
    end

    # POST /management/api/v1/servers/:server_id/http_endpoints
    # Create a new HTTP endpoint
    #
    # Required params:
    #   name - endpoint name
    #   url - HTTP(S) URL to POST to
    #
    # Optional params:
    #   encoding - "BodyAsJSON" or "FormData" (default: "BodyAsJSON")
    #   format - "Hash" or "RawMessage" (default: "Hash")
    #   strip_replies - strip reply content from messages (default: false)
    #   include_attachments - include attachments in payload (default: true)
    #   timeout - request timeout in seconds (5-60, default: 5)
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "http_endpoint": { ... }
    #   }
    # }
    def create
      server = find_server(params[:server_id])

      endpoint = server.http_endpoints.create!(
        name: api_params[:name],
        url: api_params[:url],
        encoding: api_params[:encoding] || "BodyAsJSON",
        format: api_params[:format] || "Hash",
        strip_replies: api_params[:strip_replies] == true || api_params[:strip_replies] == "true",
        include_attachments: api_params[:include_attachments] != false && api_params[:include_attachments] != "false",
        timeout: api_params[:timeout] || HTTPEndpoint::DEFAULT_TIMEOUT
      )

      render_success(http_endpoint: http_endpoint_to_hash(endpoint))
    end

    # PATCH /management/api/v1/servers/:server_id/http_endpoints/:uuid
    # Update an HTTP endpoint
    #
    # Params:
    #   name - endpoint name
    #   url - HTTP(S) URL
    #   encoding - encoding type
    #   format - format type
    #   strip_replies - strip replies
    #   include_attachments - include attachments
    #   timeout - request timeout
    def update
      server = find_server(params[:server_id])
      endpoint = server.http_endpoints.find_by!(uuid: params[:id])

      update_params = {}
      update_params[:name] = api_params[:name] if api_params[:name].present?
      update_params[:url] = api_params[:url] if api_params[:url].present?
      update_params[:encoding] = api_params[:encoding] if api_params[:encoding].present?
      update_params[:format] = api_params[:format] if api_params[:format].present?
      update_params[:timeout] = api_params[:timeout] if api_params[:timeout].present?

      if api_params.key?(:strip_replies)
        update_params[:strip_replies] = api_params[:strip_replies] == true || api_params[:strip_replies] == "true"
      end
      if api_params.key?(:include_attachments)
        update_params[:include_attachments] = api_params[:include_attachments] == true || api_params[:include_attachments] == "true"
      end

      endpoint.update!(update_params)

      render_success(http_endpoint: http_endpoint_to_hash(endpoint))
    end

    # DELETE /management/api/v1/servers/:server_id/http_endpoints/:uuid
    # Delete an HTTP endpoint
    def destroy
      server = find_server(params[:server_id])
      endpoint = server.http_endpoints.find_by!(uuid: params[:id])

      # Check if endpoint is used by routes
      if endpoint.routes.any?
        render_error "InUse", message: "Endpoint is used by #{endpoint.routes.count} route(s). Routes will be set to Reject mode."
      end

      endpoint.destroy!
      render_success(message: "HTTP endpoint '#{endpoint.name}' has been deleted")
    end

    private

    def http_endpoint_to_hash(endpoint, include_routes: false)
      hash = {
        uuid: endpoint.uuid,
        name: endpoint.name,
        url: endpoint.url,
        encoding: endpoint.encoding,
        format: endpoint.format,
        strip_replies: endpoint.strip_replies,
        include_attachments: endpoint.include_attachments,
        timeout: endpoint.timeout,
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
