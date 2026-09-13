# frozen_string_literal: true

require "uri"

module API
  module V2
    class IncomingRoutesController < BaseController

      before_action { @organization = scoped_organization!(params[:organization_uuid]) }
      before_action { @server = @organization&.servers&.present&.find_by!(uuid: params[:server_uuid]) }

      def index
        require_scope!("servers:read")
        return if performed? || @server.nil?

        scope, meta = pagination_for(@server.routes.includes(:domain, :endpoint).order(:name))
        render_data(scope.map { |route| serialize(route) }, meta: meta)
      end

      def create
        require_scope!("servers:write")
        return if performed? || @server.nil?

        with_idempotency do
          domain = @server.domains.find_by!(uuid: incoming_route_params.fetch(:domain_uuid))
          return render_error("domain_not_verified", "Verify the sending domain before enabling incoming mail", status: :unprocessable_content) unless domain.verified?

          route = ApplicationRecord.transaction do
            endpoint = create_endpoint!(incoming_route_params.fetch(:destination))
            domain.update!(incoming: true)
            @server.routes.create!(name: incoming_route_params.fetch(:name), domain: domain, spam_mode: "Mark", _endpoint: "#{endpoint.class}##{endpoint.uuid}")
          end
          audit!(organization: @organization, resource: route, action: "incoming_route.created", after: serialize(route))
          render_data(serialize(route), status: :created)
        end
      rescue Postal::HTTP::BlockedDestinationError, URI::InvalidURIError, SocketError
        render_error("unsafe_http_endpoint", "The HTTP endpoint URL is not permitted", status: :unprocessable_content)
      end

      private

      def incoming_route_params
        params.permit(:domain_uuid, :name, destination: [:type, :address, :url, :hostname, :port, :ssl_mode])
      end

      def create_endpoint!(destination)
        type = destination.fetch(:type)
        case type
        when "address"
          @server.address_endpoints.create!(address: destination.fetch(:address))
        when "http"
          validate_http_destination!(destination.fetch(:url))
          @server.http_endpoints.create!(name: "Incoming #{incoming_route_params.fetch(:name)}", url: destination.fetch(:url), encoding: "BodyAsJSON", format: "Hash", include_attachments: true, strip_replies: false)
        when "smtp"
          @server.smtp_endpoints.create!(name: "Incoming #{incoming_route_params.fetch(:name)}", hostname: destination.fetch(:hostname), port: destination[:port].presence, ssl_mode: destination.fetch(:ssl_mode, "STARTTLS"))
        else
          raise ActionController::ParameterMissing, "destination.type"
        end
      end

      def validate_http_destination!(url)
        uri = URI.parse(url)
        raise URI::InvalidURIError unless uri.is_a?(URI::HTTPS) && uri.host.present?

        Postal::HTTP::AddressGuard.safe_connect_address(uri.host)
      end

      def serialize(route)
        endpoint = route.endpoint
        {
          uuid: route.uuid, name: route.name, domain_uuid: route.domain&.uuid, domain: route.domain&.name, mode: route.mode,
          enabled: route.mode == "Endpoint", endpoint: endpoint && { type: endpoint.class.name.delete_suffix("Endpoint").downcase, description: endpoint.description },
          created_at: route.created_at
        }
      end

    end
  end
end
