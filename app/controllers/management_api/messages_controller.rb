# frozen_string_literal: true

module ManagementAPI
  class MessagesController < BaseController

    # GET /management/api/v1/servers/:server_id/messages
    # List messages for a server
    #
    # Params:
    #   scope - "incoming", "outgoing", "held" (default: "outgoing")
    #   page - page number (default: 1)
    #   per_page - messages per page (default: 50, max: 100)
    #   start_date - filter by start date (ISO 8601)
    #   end_date - filter by end date (ISO 8601)
    #   status - filter by status
    #   to - filter by recipient email
    #   from - filter by sender email
    #   tag - filter by tag
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "messages": [...],
    #     "pagination": { "page": 1, "per_page": 50, "total": 1000 }
    #   }
    # }
    def index
      server = find_server(params[:server_id])

      scope = api_params[:scope] || "outgoing"
      page = (api_params[:page] || 1).to_i
      per_page = [(api_params[:per_page] || 50).to_i, 100].min

      conditions = {}
      conditions[:rcpt_to] = api_params[:to] if api_params[:to].present?
      conditions[:mail_from] = api_params[:from] if api_params[:from].present?
      conditions[:tag] = api_params[:tag] if api_params[:tag].present?
      conditions[:status] = api_params[:status] if api_params[:status].present?

      if api_params[:start_date].present?
        conditions[:timestamp] = { greater_than: Time.parse(api_params[:start_date]).to_f }
      end
      if api_params[:end_date].present?
        conditions[:timestamp] ||= {}
        conditions[:timestamp][:less_than] = Time.parse(api_params[:end_date]).to_f
      end

      messages = server.message_db.messages(
        where: conditions,
        order: :timestamp,
        direction: "desc",
        page: page,
        per_page: per_page,
        scope: scope
      )

      total = server.message_db.messages_count(where: conditions, scope: scope)

      render_success(
        messages: messages.map { |m| message_to_hash(m) },
        pagination: {
          page: page,
          per_page: per_page,
          total: total,
          total_pages: (total.to_f / per_page).ceil
        }
      )
    end

    # GET /management/api/v1/servers/:server_id/messages/:id
    # Get a specific message by ID
    #
    # Params:
    #   expansions - array of additional data to include:
    #     "status", "details", "inspection", "plain_body", "html_body",
    #     "attachments", "headers", "raw", "deliveries"
    def show
      server = find_server(params[:server_id])
      message = server.message_db.message(params[:id].to_i)

      unless message
        raise ActiveRecord::RecordNotFound, "Message not found"
      end

      expansions = api_params[:expansions] || []
      expansions = expansions.split(",") if expansions.is_a?(String)

      render_success(message: message_to_hash(message, expansions: expansions))
    end

    # POST /management/api/v1/servers/:server_id/messages/:id/retry
    # Retry delivery of a message
    def retry
      server = find_server(params[:server_id])
      message = server.message_db.message(params[:id].to_i)

      unless message
        raise ActiveRecord::RecordNotFound, "Message not found"
      end

      unless %w[HardFail SoftFail].include?(message.status)
        render_error "InvalidStatus", message: "Only failed messages can be retried"
        return
      end

      queued_message = message.add_to_message_queue(manual: true)

      if queued_message
        render_success(
          message: "Message has been queued for retry",
          queued_message_id: queued_message.id
        )
      else
        render_error "QueueFailed", message: "Failed to queue message for retry"
      end
    end

    # POST /management/api/v1/servers/:server_id/messages/:id/cancel_hold
    # Release a held message
    def cancel_hold
      server = find_server(params[:server_id])
      message = server.message_db.message(params[:id].to_i)

      unless message
        raise ActiveRecord::RecordNotFound, "Message not found"
      end

      unless message.status == "Held"
        render_error "InvalidStatus", message: "Message is not held"
        return
      end

      message.cancel_hold

      render_success(message: "Message hold has been cancelled")
    end

    # DELETE /management/api/v1/servers/:server_id/messages/:id
    # Delete a message from the queue (if queued)
    def destroy
      server = find_server(params[:server_id])
      message = server.message_db.message(params[:id].to_i)

      unless message
        raise ActiveRecord::RecordNotFound, "Message not found"
      end

      if message.queued_message
        message.queued_message.destroy
        render_success(message: "Message has been removed from queue")
      else
        render_error "NotQueued", message: "Message is not in queue"
      end
    end

    # GET /management/api/v1/servers/:server_id/messages/:id/deliveries
    # Get delivery attempts for a message
    def deliveries
      server = find_server(params[:server_id])
      message = server.message_db.message(params[:id].to_i)

      unless message
        raise ActiveRecord::RecordNotFound, "Message not found"
      end

      deliveries = message.deliveries

      render_success(
        message_id: message.id,
        deliveries: deliveries.map { |d| delivery_to_hash(d) }
      )
    end

    # GET /management/api/v1/servers/:server_id/messages/:id/activity
    # Get activity log for a message
    def activity
      server = find_server(params[:server_id])
      message = server.message_db.message(params[:id].to_i)

      unless message
        raise ActiveRecord::RecordNotFound, "Message not found"
      end

      loads = message.loads.map do |load|
        {
          type: "load",
          ip_address: load.ip_address,
          user_agent: load.user_agent,
          country: load.country,
          city: load.city,
          timestamp: load.timestamp
        }
      end

      clicks = message.clicks.map do |click|
        {
          type: "click",
          url: click.url,
          ip_address: click.ip_address,
          user_agent: click.user_agent,
          country: click.country,
          city: click.city,
          timestamp: click.timestamp
        }
      end

      activity = (loads + clicks).sort_by { |a| a[:timestamp] }.reverse

      render_success(
        message_id: message.id,
        activity: activity
      )
    end

    # GET /management/api/v1/servers/:server_id/messages/:id/plain
    # Get plain text body of a message
    def plain
      server = find_server(params[:server_id])
      message = server.message_db.message(params[:id].to_i)

      unless message
        raise ActiveRecord::RecordNotFound, "Message not found"
      end

      render_success(
        message_id: message.id,
        plain_body: message.plain_body
      )
    end

    # GET /management/api/v1/servers/:server_id/messages/:id/html
    # Get HTML body of a message
    def html
      server = find_server(params[:server_id])
      message = server.message_db.message(params[:id].to_i)

      unless message
        raise ActiveRecord::RecordNotFound, "Message not found"
      end

      render_success(
        message_id: message.id,
        html_body: message.html_body
      )
    end

    # GET /management/api/v1/servers/:server_id/messages/:id/headers
    # Get message headers
    def headers
      server = find_server(params[:server_id])
      message = server.message_db.message(params[:id].to_i)

      unless message
        raise ActiveRecord::RecordNotFound, "Message not found"
      end

      render_success(
        message_id: message.id,
        headers: message.headers
      )
    end

    # GET /management/api/v1/servers/:server_id/messages/:id/raw
    # Get raw message data
    def raw
      server = find_server(params[:server_id])
      message = server.message_db.message(params[:id].to_i)

      unless message
        raise ActiveRecord::RecordNotFound, "Message not found"
      end

      raw_message = message.raw_message

      unless raw_message
        render_error "NoRawMessage", message: "Raw message data is not available"
        return
      end

      render_success(
        message_id: message.id,
        raw_message: Base64.encode64(raw_message)
      )
    end

    # GET /management/api/v1/servers/:server_id/messages/:id/spam_checks
    # Get spam check results for a message
    def spam_checks
      server = find_server(params[:server_id])
      message = server.message_db.message(params[:id].to_i)

      unless message
        raise ActiveRecord::RecordNotFound, "Message not found"
      end

      render_success(
        message_id: message.id,
        spam_score: message.spam_score,
        spam_threshold: server.spam_threshold,
        is_spam: message.spam_score.to_f > server.spam_threshold.to_f,
        spam_checks: message.spam_checks
      )
    end

    private

    def message_to_hash(message, expansions: [])
      hash = {
        id: message.id,
        token: message.token,
        scope: message.scope,
        mail_from: message.mail_from,
        rcpt_to: message.rcpt_to,
        subject: message.subject,
        message_id: message.message_id,
        timestamp: message.timestamp,
        status: message.status,
        tag: message.tag,
        size: message.size,
        spam_score: message.spam_score,
        bounce: message.bounce,
        credential_id: message.credential_id
      }

      if expansions.include?("status") || expansions.include?("all")
        hash[:status_details] = {
          status: message.status,
          last_delivery_attempt: message.last_delivery_attempt,
          held: message.held?,
          hold_expiry: message.hold_expiry
        }
      end

      if expansions.include?("details") || expansions.include?("all")
        hash[:details] = {
          received_with_ssl: message.received_with_ssl,
          domain_id: message.domain_id,
          route_id: message.route_id,
          endpoint_id: message.endpoint_id,
          endpoint_type: message.endpoint_type
        }
      end

      if expansions.include?("inspection") || expansions.include?("all")
        hash[:inspection] = message.inspected_data
      end

      if expansions.include?("plain_body") || expansions.include?("all")
        hash[:plain_body] = message.plain_body
      end

      if expansions.include?("html_body") || expansions.include?("all")
        hash[:html_body] = message.html_body
      end

      if expansions.include?("attachments") || expansions.include?("all")
        hash[:attachments] = message.attachments.map do |a|
          {
            filename: a.filename,
            content_type: a.content_type,
            size: a.size,
            hash: a.hash
          }
        end
      end

      if expansions.include?("headers") || expansions.include?("all")
        hash[:headers] = message.headers
      end

      if expansions.include?("deliveries") || expansions.include?("all")
        hash[:deliveries] = message.deliveries.map { |d| delivery_to_hash(d) }
      end

      hash
    end

    def delivery_to_hash(delivery)
      {
        id: delivery.id,
        status: delivery.status,
        details: delivery.details,
        output: delivery.output,
        sent_with_ssl: delivery.sent_with_ssl,
        log_id: delivery.log_id,
        timestamp: delivery.timestamp
      }
    end

  end
end
