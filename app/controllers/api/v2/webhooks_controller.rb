# frozen_string_literal: true

require "uri"

module API
  module V2
    class WebhooksController < BaseController

      before_action { @organization = scoped_organization!(params[:organization_uuid]) }
      before_action { @server = @organization&.servers&.present&.find_by!(uuid: params[:server_uuid]) }
      before_action(only: [:show, :update, :destroy]) do
        @webhook = @server&.webhooks&.find_by!(uuid: params[:uuid])
      end

      def index
        require_scope!("servers:read")
        return if performed? || @server.nil?

        scope, meta = pagination_for(@server.webhooks.order(:name))
        render_data(scope.map { |webhook| serialize(webhook) }, meta: meta)
      end

      def show
        require_scope!("servers:read")
        return if performed? || @webhook.nil?

        render_data(serialize(@webhook))
      end

      def create
        require_scope!("servers:write")
        return if performed? || @server.nil?

        with_idempotency do
          validate_destination!(webhook_params[:url])
          webhook = @server.webhooks.create!(webhook_create_params)
          audit!(organization: @organization, resource: webhook, action: "webhook.created", after: serialize(webhook))
          render_data(serialize(webhook), status: :created)
        end
      rescue Postal::HTTP::BlockedDestinationError, URI::InvalidURIError, SocketError
        render_error("unsafe_webhook_url", "The webhook URL is not permitted", status: :unprocessable_content)
      end

      def update
        require_scope!("servers:write")
        return if performed? || @webhook.nil?

        with_idempotency do
          validate_destination!(webhook_params.fetch(:url, @webhook.url))
          @webhook.update!(webhook_params)
          audit!(organization: @organization, resource: @webhook, action: "webhook.updated", after: serialize(@webhook))
          render_data(serialize(@webhook))
        end
      rescue Postal::HTTP::BlockedDestinationError, URI::InvalidURIError, SocketError
        render_error("unsafe_webhook_url", "The webhook URL is not permitted", status: :unprocessable_content)
      end

      def destroy
        require_scope!("servers:write")
        return if performed? || @webhook.nil?

        with_idempotency do
          @webhook.destroy!
          audit!(organization: @organization, resource: @webhook, action: "webhook.deleted")
          head :no_content
        end
      end

      private

      def webhook_params
        params.permit(:name, :url, :all_events, :enabled, events: [])
      end

      def webhook_create_params
        webhook_params.tap do |attributes|
          attributes[:all_events] = true if attributes[:all_events].nil? && attributes[:events].blank?
        end
      end

      def validate_destination!(url)
        raise URI::InvalidURIError if url.blank?

        uri = URI.parse(url)
        raise URI::InvalidURIError unless uri.is_a?(URI::HTTPS) && uri.host.present?

        Postal::HTTP::AddressGuard.safe_connect_address(uri.host)
      end

      def serialize(webhook)
        { uuid: webhook.uuid, name: webhook.name, url: webhook.url, all_events: webhook.all_events, events: webhook.events, enabled: webhook.enabled, last_used_at: webhook.last_used_at }
      end

    end
  end
end
