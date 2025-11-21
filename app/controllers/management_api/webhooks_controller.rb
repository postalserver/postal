# frozen_string_literal: true

module ManagementAPI
  class WebhooksController < BaseController

    # Available webhook events
    WEBHOOK_EVENTS = %w[
      MessageSent
      MessageDelayed
      MessageDeliveryFailed
      MessageHeld
      MessageBounced
      MessageLinkClicked
      MessageLoaded
      DomainDNSError
    ].freeze

    # GET /management/api/v1/servers/:server_id/webhooks
    # List all webhooks for a server
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "webhooks": [
    #       { "uuid": "xxx", "name": "Bounces", "url": "https://...", "events": [...] }
    #     ]
    #   }
    # }
    def index
      server = find_server(params[:server_id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      render_success(
        server: server.full_permalink,
        webhooks: server.webhooks.includes(:webhook_events).map { |w| webhook_to_hash(w) },
        available_events: WEBHOOK_EVENTS
      )
    end

    # GET /management/api/v1/servers/:server_id/webhooks/:id
    # Get a specific webhook
    def show
      server = find_server(params[:server_id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      webhook = server.webhooks.includes(:webhook_events).find_by!(uuid: params[:id])

      render_success(webhook: webhook_to_hash(webhook))
    end

    # POST /management/api/v1/servers/:server_id/webhooks
    # Create a new webhook
    #
    # Required params:
    #   name - webhook name
    #   url - webhook URL (must be http:// or https://)
    #
    # Optional params:
    #   enabled - true/false (default: true)
    #   all_events - if true, receive all events (default: false)
    #   sign - if true, requests are signed (default: true)
    #   events - array of event names to subscribe to
    #            Available: MessageSent, MessageDelayed, MessageDeliveryFailed,
    #                       MessageHeld, MessageBounced, MessageLinkClicked,
    #                       MessageLoaded, DomainDNSError
    #
    # Example for bounces only:
    # {
    #   "name": "Bounce Handler",
    #   "url": "https://example.com/bounces",
    #   "events": ["MessageDeliveryFailed", "MessageBounced"]
    # }
    def create
      server = find_server(params[:server_id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      webhook = server.webhooks.build(
        name: api_params[:name],
        url: api_params[:url],
        enabled: api_params[:enabled] != false,
        all_events: api_params[:all_events] || false,
        sign: api_params[:sign] != false
      )

      # Set specific events if not using all_events
      if api_params[:events].present? && !api_params[:all_events]
        events = Array(api_params[:events]) & WEBHOOK_EVENTS
        webhook.events = events
      end

      webhook.save!

      render_success(
        webhook: webhook_to_hash(webhook),
        message: "Webhook created successfully"
      )
    end

    # PATCH /management/api/v1/servers/:server_id/webhooks/:id
    # Update a webhook
    #
    # Params:
    #   name - webhook name
    #   url - webhook URL
    #   enabled - true/false
    #   all_events - true/false
    #   sign - true/false
    #   events - array of event names
    def update
      server = find_server(params[:server_id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      webhook = server.webhooks.find_by!(uuid: params[:id])

      webhook.name = api_params[:name] if api_params[:name].present?
      webhook.url = api_params[:url] if api_params[:url].present?
      webhook.enabled = api_params[:enabled] if api_params.key?(:enabled)
      webhook.all_events = api_params[:all_events] if api_params.key?(:all_events)
      webhook.sign = api_params[:sign] if api_params.key?(:sign)

      if api_params[:events].present?
        events = Array(api_params[:events]) & WEBHOOK_EVENTS
        webhook.events = events
      end

      webhook.save!

      render_success(webhook: webhook_to_hash(webhook))
    end

    # DELETE /management/api/v1/servers/:server_id/webhooks/:id
    # Delete a webhook
    def destroy
      server = find_server(params[:server_id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      webhook = server.webhooks.find_by!(uuid: params[:id])
      webhook.destroy!

      render_success(message: "Webhook '#{webhook.name}' has been deleted")
    end

    private

    def webhook_to_hash(webhook)
      {
        uuid: webhook.uuid,
        name: webhook.name,
        url: webhook.url,
        enabled: webhook.enabled?,
        all_events: webhook.all_events?,
        sign: webhook.sign?,
        events: webhook.all_events? ? WEBHOOK_EVENTS : webhook.events,
        last_used_at: webhook.last_used_at,
        created_at: webhook.created_at,
        updated_at: webhook.updated_at
      }
    end

  end
end
