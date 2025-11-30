# frozen_string_literal: true

module ManagementAPI
  module V2
    class WebhooksController < BaseController

      before_action :find_server!
      before_action :check_server_access!
      before_action :find_webhook!, only: [:show, :update, :destroy, :test]

      # GET /api/v2/management/servers/:server_uuid/webhooks
      def index
        webhooks = @server.webhooks.includes(:webhook_events)
        webhooks = filter_webhooks(webhooks)
        webhooks = webhooks.order(created_at: :desc)
        webhooks, meta = paginate(webhooks)

        render_success(
          webhooks.map { |w| webhook_json(w) },
          meta: meta
        )
      end

      # GET /api/v2/management/servers/:server_uuid/webhooks/:uuid
      def show
        render_success(webhook_json(@webhook, detailed: true))
      end

      # POST /api/v2/management/servers/:server_uuid/webhooks
      def create
        @webhook = @server.webhooks.new(webhook_params)

        if params[:events].is_a?(Array) && !params[:all_events]
          @webhook.events = params[:events]
        end

        @webhook.save!
        render_success(webhook_json(@webhook, detailed: true), status: :created)
      end

      # PATCH /api/v2/management/servers/:server_uuid/webhooks/:uuid
      def update
        @webhook.assign_attributes(webhook_update_params)

        if params.key?(:events) && !@webhook.all_events?
          @webhook.events = params[:events] || []
        end

        @webhook.save!
        render_success(webhook_json(@webhook, detailed: true))
      end

      # DELETE /api/v2/management/servers/:server_uuid/webhooks/:uuid
      def destroy
        @webhook.destroy!
        render_success({ deleted: true, uuid: @webhook.uuid })
      end

      # POST /api/v2/management/servers/:server_uuid/webhooks/:uuid/test
      def test
        event = params[:event] || "MessageSent"

        unless @webhook.all_events? || @webhook.events.include?(event)
          render_error("EventNotEnabled", "Event '#{event}' is not enabled for this webhook")
          return
        end

        # Send test request directly using Postal::HTTP
        start_time = Time.now
        payload = test_payload(event).to_json

        begin
          result = Postal::HTTP.post(
            @webhook.url,
            sign: @webhook.sign?,
            json: payload,
            timeout: 10
          )

          response_time = ((Time.now - start_time) * 1000).round(2)
          success = result[:code] >= 200 && result[:code] < 300

          render_success({
            success: success,
            event: event,
            url: @webhook.url,
            response_code: result[:code],
            response_time_ms: response_time,
            response_body: result[:body]&.truncate(500)
          })
        rescue StandardError => e
          render_success({
            success: false,
            event: event,
            url: @webhook.url,
            error: e.message
          })
        end
      end

      private

      def find_webhook!
        @webhook = @server.webhooks.find_by!(uuid: params[:uuid])
      end

      def check_server_access!
        return if current_api_key.super_admin?
        return if current_api_key.can_access_organization?(@server.organization)

        render_error("Forbidden", "You don't have access to this server", status: :forbidden)
      end

      def filter_webhooks(scope)
        scope = scope.where("name LIKE ?", "%#{params[:name]}%") if params[:name].present?
        scope = scope.where(enabled: true) if params[:enabled] == "true"
        scope = scope.where(enabled: false) if params[:enabled] == "false"
        scope
      end

      def webhook_params
        params.permit(:name, :url, :enabled, :all_events, :sign)
      end

      def webhook_update_params
        params.permit(:name, :url, :enabled, :all_events, :sign)
      end

      def webhook_json(webhook, detailed: false)
        data = {
          uuid: webhook.uuid,
          name: webhook.name,
          url: webhook.url,
          enabled: webhook.enabled,
          all_events: webhook.all_events,
          sign: webhook.sign,
          last_used_at: webhook.last_used_at&.iso8601,
          created_at: webhook.created_at.iso8601,
          updated_at: webhook.updated_at.iso8601
        }

        data[:events] = webhook.all_events? ? WebhookEvent::EVENTS : webhook.events

        if detailed
          data[:available_events] = WebhookEvent::EVENTS
          data[:recent_requests] = webhook.webhook_requests.order(created_at: :desc).limit(5).map do |req|
            {
              uuid: req.uuid,
              event: req.event,
              attempts: req.attempts,
              created_at: req.created_at.iso8601
            }
          end
        end

        data
      end

      def test_payload(event)
        {
          event: event,
          timestamp: Time.current.to_f,
          payload: {
            test: true,
            message: "This is a test webhook from Postal Management API",
            server: {
              uuid: @server.uuid,
              name: @server.name
            }
          }
        }
      end

    end
  end
end
