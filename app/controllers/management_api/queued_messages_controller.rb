# frozen_string_literal: true

module ManagementAPI
  class QueuedMessagesController < BaseController

    # GET /management/api/v1/servers/:server_id/queue
    # List queued messages for a server
    #
    # Params:
    #   page - page number (default: 1)
    #   per_page - items per page (default: 50, max: 100)
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "queued_messages": [...],
    #     "pagination": { ... }
    #   }
    # }
    def index
      server = find_server(params[:server_id])

      page = (api_params[:page] || 1).to_i
      per_page = [(api_params[:per_page] || 50).to_i, 100].min

      queued = server.queued_messages
        .order(created_at: :desc)
        .page(page)
        .per(per_page)

      total = server.queued_messages.count

      render_success(
        queued_messages: queued.map { |q| queued_message_to_hash(q, server) },
        pagination: {
          page: page,
          per_page: per_page,
          total: total,
          total_pages: (total.to_f / per_page).ceil
        }
      )
    end

    # GET /management/api/v1/servers/:server_id/queue/summary
    # Get queue summary for a server
    def summary
      server = find_server(params[:server_id])

      queued = server.queued_messages

      render_success(
        summary: {
          total: queued.count,
          by_status: {
            pending: queued.where(locked_at: nil).count,
            locked: queued.where.not(locked_at: nil).count
          },
          oldest: queued.minimum(:created_at),
          newest: queued.maximum(:created_at)
        }
      )
    end

    # GET /management/api/v1/servers/:server_id/queue/:id
    # Get a specific queued message
    def show
      server = find_server(params[:server_id])
      queued = server.queued_messages.find(params[:id])

      render_success(queued_message: queued_message_to_hash(queued, server, include_details: true))
    end

    # DELETE /management/api/v1/servers/:server_id/queue/:id
    # Remove a message from the queue
    def destroy
      server = find_server(params[:server_id])
      queued = server.queued_messages.find(params[:id])

      queued.destroy!
      render_success(message: "Message has been removed from queue")
    end

    # POST /management/api/v1/servers/:server_id/queue/:id/retry
    # Retry a queued message immediately
    def retry_now
      server = find_server(params[:server_id])
      queued = server.queued_messages.find(params[:id])

      # Unlock and reset retry time to allow immediate processing
      queued.update!(
        locked_at: nil,
        locked_by: nil,
        retry_after: nil
      )

      render_success(message: "Message has been unlocked for immediate retry")
    end

    # DELETE /management/api/v1/servers/:server_id/queue/clear
    # Clear all queued messages for a server
    def clear
      server = find_server(params[:server_id])

      count = server.queued_messages.count
      server.queued_messages.destroy_all

      render_success(
        message: "Queue has been cleared",
        removed: count
      )
    end

    # POST /management/api/v1/servers/:server_id/queue/retry_all
    # Retry all queued messages
    def retry_all
      server = find_server(params[:server_id])

      count = server.queued_messages.update_all(
        locked_at: nil,
        locked_by: nil,
        retry_after: nil
      )

      render_success(
        message: "All queued messages have been unlocked for retry",
        affected: count
      )
    end

    private

    def queued_message_to_hash(queued, server, include_details: false)
      hash = {
        id: queued.id,
        message_id: queued.message_id,
        domain: queued.domain,
        locked_at: queued.locked_at,
        locked_by: queued.locked_by,
        retry_after: queued.retry_after,
        attempts: queued.attempts,
        created_at: queued.created_at,
        updated_at: queued.updated_at
      }

      if include_details
        message = server.message_db.message(queued.message_id)
        if message
          hash[:message] = {
            mail_from: message.mail_from,
            rcpt_to: message.rcpt_to,
            subject: message.subject,
            status: message.status,
            timestamp: message.timestamp
          }
        end
      end

      hash
    end

  end
end
