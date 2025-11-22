# frozen_string_literal: true

module ManagementAPI
  class MessagesController < BaseController

    before_action :set_server
    before_action :set_message, only: [:show, :deliveries, :retry, :cancel_hold]

    # GET /api/v2/management/servers/:server_id/messages
    def index
      authorize!(:messages, :read)

      scope_type = api_params[:scope] || "all"
      page = (api_params[:page] || 1).to_i
      per_page = [(api_params[:per_page] || 25).to_i, 100].min

      where_conditions = {}
      where_conditions[:scope] = api_params[:direction] if api_params[:direction].present?
      where_conditions[:rcpt_to] = api_params[:to] if api_params[:to].present?
      where_conditions[:mail_from] = api_params[:from] if api_params[:from].present?
      where_conditions[:status] = api_params[:status] if api_params[:status].present?
      where_conditions[:held] = true if scope_type == "held"

      messages = @server.message_db.messages(
        where: where_conditions,
        order: :timestamp,
        direction: "desc",
        page: page,
        per_page: per_page
      )

      total = @server.message_db.messages(where: where_conditions, count: true)

      render_success(
        messages.map { |m| serialize_message(m) },
        meta: {
          page: page,
          per_page: per_page,
          total: total,
          total_pages: (total.to_f / per_page).ceil
        }
      )
    end

    # GET /api/v2/management/servers/:server_id/messages/:id
    def show
      authorize!(:messages, :read)
      render_success(serialize_message(@message, detailed: true))
    end

    # GET /api/v2/management/servers/:server_id/messages/:id/deliveries
    def deliveries
      authorize!(:messages, :read)

      deliveries = @message.deliveries

      render_success(deliveries.map { |d| serialize_delivery(d) })
    end

    # POST /api/v2/management/servers/:server_id/messages/:id/retry
    def retry
      authorize!(:messages, :write)

      if @message.queued_message.nil?
        render_error("NotQueued", "This message is not in the queue", 400)
        return
      end

      @message.queued_message.retry_now
      render_success({ retried: true, message_id: @message.id })
    end

    # POST /api/v2/management/servers/:server_id/messages/:id/cancel_hold
    def cancel_hold
      authorize!(:messages, :write)

      unless @message.held?
        render_error("NotHeld", "This message is not held", 400)
        return
      end

      @message.cancel_hold
      render_success({ hold_cancelled: true, message_id: @message.id })
    end

    # GET /api/v2/management/servers/:server_id/queue
    def queue
      authorize!(:messages, :read)

      page = (api_params[:page] || 1).to_i
      per_page = [(api_params[:per_page] || 25).to_i, 100].min

      scope = @server.queued_messages.ready.order(created_at: :desc)
      total = scope.count
      records = scope.offset((page - 1) * per_page).limit(per_page)

      render_success(
        records.map { |qm| serialize_queued_message(qm) },
        meta: {
          page: page,
          per_page: per_page,
          total: total,
          total_pages: (total.to_f / per_page).ceil
        }
      )
    end

    private

    def set_server
      @server = current_api_key.accessible_servers.find_by!(uuid: params[:server_id])
    rescue ActiveRecord::RecordNotFound
      @server = current_api_key.accessible_servers.find_by!(token: params[:server_id])
    end

    def set_message
      @message = @server.message(params[:id].to_i)
      raise ActiveRecord::RecordNotFound, "Message not found" if @message.nil?
    end

    def serialize_message(message, detailed: false)
      data = {
        id: message.id,
        token: message.token,
        scope: message.scope,
        status: message.status,
        mail_from: message.mail_from,
        rcpt_to: message.rcpt_to,
        subject: message.subject,
        held: message.held?,
        timestamp: message.timestamp&.iso8601,
        message_id: message.message_id
      }

      if detailed
        data.merge!(
          size: message.size,
          bounce: message.bounce?,
          spam: message.spam?,
          spam_score: message.spam_score,
          threat: message.threat?,
          threat_details: message.threat_details,
          received_with_ssl: message.received_with_ssl?,
          inspected: message.inspected?,
          tag: message.tag,
          raw_message_available: message.raw_message.present?
        )
      end

      data
    end

    def serialize_delivery(delivery)
      {
        id: delivery.id,
        status: delivery.status,
        details: delivery.details,
        output: delivery.output,
        sent_with_ssl: delivery.sent_with_ssl?,
        log_id: delivery.log_id,
        timestamp: delivery.timestamp&.iso8601
      }
    end

    def serialize_queued_message(qm)
      {
        id: qm.id,
        message_id: qm.message_id,
        domain: qm.domain,
        locked_by: qm.locked_by,
        locked_at: qm.locked_at&.iso8601,
        retry_after: qm.retry_after&.iso8601,
        attempts: qm.attempts,
        created_at: qm.created_at&.iso8601
      }
    end

  end
end
