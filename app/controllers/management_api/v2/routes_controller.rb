# frozen_string_literal: true

module ManagementAPI
  module V2
    class RoutesController < BaseController

      before_action :find_server!
      before_action :check_server_access!
      before_action :find_route!, only: [:show, :update, :destroy]

      # GET /api/v2/management/servers/:server_uuid/routes
      def index
        routes = @server.routes.includes(:domain, :endpoint)
        routes = routes.order(created_at: :desc)
        routes, meta = paginate(routes)

        render_success(
          routes.map { |r| route_json(r) },
          meta: meta
        )
      end

      # GET /api/v2/management/servers/:server_uuid/routes/:uuid
      def show
        render_success(route_json(@route, detailed: true))
      end

      # POST /api/v2/management/servers/:server_uuid/routes
      def create
        @route = @server.routes.new(route_params)

        # Find domain by name if provided
        if params[:domain_name].present?
          domain = @server.domains.verified.find_by(name: params[:domain_name])
          domain ||= @server.organization.domains.verified.find_by(name: params[:domain_name])
          if domain.nil?
            render_error("DomainNotFound", "Verified domain '#{params[:domain_name]}' not found")
            return
          end
          @route.domain = domain
        end

        # Handle endpoint creation or assignment
        if params[:endpoint].present?
          endpoint = create_or_find_endpoint(params[:endpoint])
          return if performed?

          @route.endpoint = endpoint
          @route.mode = "Endpoint"
        elsif params[:mode].present?
          @route.mode = params[:mode]
        end

        @route.save!
        render_success(route_json(@route, detailed: true), status: :created)
      end

      # PATCH /api/v2/management/servers/:server_uuid/routes/:uuid
      def update
        @route.assign_attributes(route_update_params)

        if params[:endpoint].present?
          endpoint = create_or_find_endpoint(params[:endpoint])
          return if performed?

          @route.endpoint = endpoint
          @route.mode = "Endpoint"
        elsif params[:mode].present? && params[:mode] != "Endpoint"
          @route.mode = params[:mode]
          @route.endpoint = nil
        end

        @route.save!
        render_success(route_json(@route, detailed: true))
      end

      # DELETE /api/v2/management/servers/:server_uuid/routes/:uuid
      def destroy
        @route.destroy!
        render_success({ deleted: true, uuid: @route.uuid })
      end

      private

      def find_route!
        @route = @server.routes.find_by!(uuid: params[:uuid])
      end

      def check_server_access!
        return if current_api_key.super_admin?
        return if current_api_key.can_access_organization?(@server.organization)

        render_error("Forbidden", "You don't have access to this server", status: :forbidden)
      end

      def route_params
        params.permit(:name, :spam_mode)
      end

      def route_update_params
        params.permit(:name, :spam_mode)
      end

      def create_or_find_endpoint(endpoint_params)
        type = endpoint_params[:type]&.downcase

        case type
        when "http"
          create_http_endpoint(endpoint_params)
        when "smtp"
          create_smtp_endpoint(endpoint_params)
        when "address"
          create_address_endpoint(endpoint_params)
        when "existing"
          find_existing_endpoint(endpoint_params)
        else
          render_error("InvalidEndpointType", "Endpoint type must be one of: http, smtp, address, existing")
          nil
        end
      end

      def create_http_endpoint(params)
        endpoint = @server.http_endpoints.new(
          name: params[:name],
          url: params[:url],
          encoding: params[:encoding] || "BodyAsJSON",
          format: params[:format] || "Hash",
          strip_replies: params[:strip_replies] || false,
          include_attachments: params.fetch(:include_attachments, true),
          timeout: params[:timeout] || HTTPEndpoint::DEFAULT_TIMEOUT
        )
        endpoint.save!
        endpoint
      rescue ActiveRecord::RecordInvalid => e
        render_error("EndpointValidationError", "Failed to create HTTP endpoint", details: e.record.errors.to_hash)
        nil
      end

      def create_smtp_endpoint(params)
        endpoint = @server.smtp_endpoints.new(
          name: params[:name],
          hostname: params[:hostname],
          port: params[:port] || 25,
          ssl_mode: params[:ssl_mode] || "Auto"
        )
        endpoint.save!
        endpoint
      rescue ActiveRecord::RecordInvalid => e
        render_error("EndpointValidationError", "Failed to create SMTP endpoint", details: e.record.errors.to_hash)
        nil
      end

      def create_address_endpoint(params)
        endpoint = @server.address_endpoints.find_or_initialize_by(address: params[:address])
        endpoint.save!
        endpoint
      rescue ActiveRecord::RecordInvalid => e
        render_error("EndpointValidationError", "Failed to create address endpoint", details: e.record.errors.to_hash)
        nil
      end

      def find_existing_endpoint(params)
        uuid = params[:uuid]
        endpoint_type = params[:endpoint_type]

        unless uuid.present? && endpoint_type.present?
          render_error("MissingEndpointInfo", "Both uuid and endpoint_type are required for existing endpoints")
          return nil
        end

        case endpoint_type.downcase
        when "http"
          @server.http_endpoints.find_by!(uuid: uuid)
        when "smtp"
          @server.smtp_endpoints.find_by!(uuid: uuid)
        when "address"
          @server.address_endpoints.find_by!(uuid: uuid)
        else
          render_error("InvalidEndpointType", "Endpoint type must be one of: http, smtp, address")
          nil
        end
      rescue ActiveRecord::RecordNotFound
        render_error("EndpointNotFound", "Endpoint with uuid '#{uuid}' not found")
        nil
      end

      def route_json(route, detailed: false)
        data = {
          uuid: route.uuid,
          name: route.name,
          description: route.description,
          domain: route.domain ? { uuid: route.domain.uuid, name: route.domain.name } : nil,
          mode: route.mode,
          spam_mode: route.spam_mode,
          token: route.token,
          forward_address: route.forward_address,
          wildcard: route.wildcard?,
          return_path: route.return_path?,
          created_at: route.created_at.iso8601,
          updated_at: route.updated_at.iso8601
        }

        if route.mode == "Endpoint" && route.endpoint
          data[:endpoint] = endpoint_json(route.endpoint)
        end

        if detailed && route.additional_route_endpoints.any?
          data[:additional_endpoints] = route.additional_route_endpoints.map do |are|
            endpoint_json(are.endpoint) if are.endpoint
          end.compact
        end

        data
      end

      def endpoint_json(endpoint)
        data = {
          type: endpoint.class.name.sub("Endpoint", "").downcase,
          uuid: endpoint.uuid,
          description: endpoint.description
        }

        case endpoint
        when HTTPEndpoint
          data[:url] = endpoint.url
          data[:encoding] = endpoint.encoding
          data[:format] = endpoint.format
          data[:include_attachments] = endpoint.include_attachments
          data[:timeout] = endpoint.timeout
        when SMTPEndpoint
          data[:hostname] = endpoint.hostname
          data[:port] = endpoint.port
          data[:ssl_mode] = endpoint.ssl_mode
        when AddressEndpoint
          data[:address] = endpoint.address
        end

        data
      end

    end
  end
end
