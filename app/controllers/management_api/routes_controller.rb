# frozen_string_literal: true

module ManagementAPI
  class RoutesController < BaseController

    before_action :set_server
    before_action :set_route, only: [:show, :update, :destroy]

    # GET /api/v2/management/servers/:server_id/routes
    def index
      authorize!(:routes, :read)

      scope = @server.routes.includes(:domain, :endpoint).order(created_at: :desc)

      # Filtering
      scope = scope.where("name LIKE ?", "%#{api_params[:name]}%") if api_params[:name].present?

      result = paginate(scope)
      render_success(result[:records].map { |r| serialize_route(r) }, meta: result[:meta])
    end

    # GET /api/v2/management/servers/:server_id/routes/:id
    def show
      authorize!(:routes, :read)
      render_success(serialize_route(@route, detailed: true))
    end

    # POST /api/v2/management/servers/:server_id/routes
    def create
      authorize!(:routes, :write)

      route = @server.routes.new(route_params)

      # Set domain
      if api_params[:domain_uuid].present?
        domain = @server.domains.find_by!(uuid: api_params[:domain_uuid])
        route.domain = domain
      elsif api_params[:domain_name].present?
        domain = @server.domains.find_by!(name: api_params[:domain_name])
        route.domain = domain
      end

      # Set endpoint
      if api_params[:endpoint].present?
        route.endpoint = find_or_create_endpoint(api_params[:endpoint])
      end

      if route.save
        render_created(serialize_route(route, detailed: true))
      else
        render json: {
          status: "error",
          time: elapsed_time,
          error: {
            code: "ValidationError",
            message: "Failed to create route",
            details: route.errors.to_hash
          }
        }, status: :unprocessable_entity
      end
    end

    # PATCH /api/v2/management/servers/:server_id/routes/:id
    def update
      authorize!(:routes, :write)

      update_params = {
        name: api_params[:name],
        spam_mode: api_params[:spam_mode],
        mode: api_params[:mode]
      }.compact

      if @route.update(update_params)
        render_success(serialize_route(@route, detailed: true))
      else
        render json: {
          status: "error",
          time: elapsed_time,
          error: {
            code: "ValidationError",
            message: "Failed to update route",
            details: @route.errors.to_hash
          }
        }, status: :unprocessable_entity
      end
    end

    # DELETE /api/v2/management/servers/:server_id/routes/:id
    def destroy
      authorize!(:routes, :delete)

      @route.destroy
      render_deleted
    end

    private

    def set_server
      @server = current_api_key.accessible_servers.find_by!(uuid: params[:server_id])
    rescue ActiveRecord::RecordNotFound
      @server = current_api_key.accessible_servers.find_by!(token: params[:server_id])
    end

    def set_route
      @route = @server.routes.find_by!(uuid: params[:id])
    end

    def route_params
      {
        name: api_params[:name],
        spam_mode: api_params[:spam_mode] || "Mark",
        mode: api_params[:mode] || "Endpoint"
      }.compact
    end

    def find_or_create_endpoint(endpoint_config)
      case endpoint_config[:type]
      when "http"
        @server.http_endpoints.find_or_create_by!(url: endpoint_config[:url]) do |ep|
          ep.name = endpoint_config[:name] || "HTTP Endpoint"
          ep.encoding = endpoint_config[:encoding] || "BodyAsJSON"
          ep.format = endpoint_config[:format] || "Hash"
          ep.include_attachments = endpoint_config[:include_attachments] || false
        end
      when "smtp"
        @server.smtp_endpoints.find_or_create_by!(hostname: endpoint_config[:hostname], port: endpoint_config[:port] || 25) do |ep|
          ep.name = endpoint_config[:name] || "SMTP Endpoint"
          ep.ssl_mode = endpoint_config[:ssl_mode] || "Auto"
        end
      when "address"
        @server.address_endpoints.find_or_create_by!(address: endpoint_config[:address]) do |ep|
          ep.name = endpoint_config[:name] || "Address Endpoint"
        end
      end
    end

    def serialize_route(route, detailed: false)
      data = {
        uuid: route.uuid,
        name: route.name,
        mode: route.mode,
        spam_mode: route.spam_mode,
        domain: route.domain ? { uuid: route.domain.uuid, name: route.domain.name } : nil,
        created_at: route.created_at&.iso8601,
        updated_at: route.updated_at&.iso8601
      }

      if detailed && route.endpoint
        data[:endpoint] = {
          type: route.endpoint.class.name.underscore.gsub("_endpoint", ""),
          uuid: route.endpoint.uuid,
          name: route.endpoint.name
        }

        case route.endpoint
        when HttpEndpoint
          data[:endpoint].merge!(
            url: route.endpoint.url,
            encoding: route.endpoint.encoding,
            format: route.endpoint.format,
            include_attachments: route.endpoint.include_attachments
          )
        when SmtpEndpoint
          data[:endpoint].merge!(
            hostname: route.endpoint.hostname,
            port: route.endpoint.port,
            ssl_mode: route.endpoint.ssl_mode
          )
        when AddressEndpoint
          data[:endpoint].merge!(
            address: route.endpoint.address
          )
        end
      end

      data
    end

  end
end
