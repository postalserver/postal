# frozen_string_literal: true

module ManagementApi
  class WebhooksController < BaseController

    before_action :set_server
    before_action :set_webhook, only: [:show, :update, :destroy, :test]

    # GET /api/v2/management/servers/:server_id/webhooks
    def index
      authorize!(:webhooks, :read)

      scope = @server.webhooks.order(created_at: :desc)

      # Filtering
      scope = scope.where("name LIKE ?", "%#{api_params[:name]}%") if api_params[:name].present?
      scope = scope.where(enabled: true) if api_params[:enabled] == "true"
      scope = scope.where(enabled: false) if api_params[:enabled] == "false"

      result = paginate(scope)
      render_success(result[:records].map { |w| serialize_webhook(w) }, meta: result[:meta])
    end

    # GET /api/v2/management/servers/:server_id/webhooks/:id
    def show
      authorize!(:webhooks, :read)
      render_success(serialize_webhook(@webhook, detailed: true))
    end

    # POST /api/v2/management/servers/:server_id/webhooks
    def create
      authorize!(:webhooks, :write)

      webhook = @server.webhooks.new(webhook_params)

      if webhook.save
        render_created(serialize_webhook(webhook, detailed: true))
      else
        render json: {
          status: "error",
          time: elapsed_time,
          error: {
            code: "ValidationError",
            message: "Failed to create webhook",
            details: webhook.errors.to_hash
          }
        }, status: :unprocessable_entity
      end
    end

    # PATCH /api/v2/management/servers/:server_id/webhooks/:id
    def update
      authorize!(:webhooks, :write)

      if @webhook.update(webhook_params)
        render_success(serialize_webhook(@webhook, detailed: true))
      else
        render json: {
          status: "error",
          time: elapsed_time,
          error: {
            code: "ValidationError",
            message: "Failed to update webhook",
            details: @webhook.errors.to_hash
          }
        }, status: :unprocessable_entity
      end
    end

    # DELETE /api/v2/management/servers/:server_id/webhooks/:id
    def destroy
      authorize!(:webhooks, :delete)

      @webhook.destroy
      render_deleted
    end

    # POST /api/v2/management/servers/:server_id/webhooks/:id/test
    def test
      authorize!(:webhooks, :write)

      # Trigger a test webhook event
      test_payload = {
        event: "test",
        timestamp: Time.current.iso8601,
        server: @server.webhook_hash,
        test: true,
        message: "This is a test webhook from Postal Management API"
      }

      begin
        response = HTTP.timeout(10)
                      .headers("Content-Type" => "application/json")
                      .post(@webhook.url, json: test_payload)

        render_success({
          webhook_uuid: @webhook.uuid,
          test_sent: true,
          response: {
            status: response.status.to_i,
            body: response.body.to_s.truncate(1000)
          }
        })
      rescue => e
        render_error("WebhookTestFailed", "Failed to send test webhook: #{e.message}", 500)
      end
    end

    private

    def set_server
      @server = current_api_key.accessible_servers.find_by!(uuid: params[:server_id])
    rescue ActiveRecord::RecordNotFound
      @server = current_api_key.accessible_servers.find_by!(token: params[:server_id])
    end

    def set_webhook
      @webhook = @server.webhooks.find_by!(uuid: params[:id])
    end

    def webhook_params
      {
        name: api_params[:name],
        url: api_params[:url],
        enabled: api_params[:enabled],
        all_events: api_params[:all_events],
        sign: api_params[:sign]
      }.compact
    end

    def serialize_webhook(webhook, detailed: false)
      data = {
        uuid: webhook.uuid,
        name: webhook.name,
        url: webhook.url,
        enabled: webhook.enabled,
        all_events: webhook.all_events,
        created_at: webhook.created_at&.iso8601,
        updated_at: webhook.updated_at&.iso8601
      }

      if detailed
        data.merge!(
          sign: webhook.sign,
          last_used_at: webhook.last_used_at&.iso8601
        )
      end

      data
    end

  end
end
