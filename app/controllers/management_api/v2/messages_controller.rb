# frozen_string_literal: true

module ManagementAPI
  module V2
    class MessagesController < BaseController

      before_action :find_server!
      before_action :check_server_access!
      before_action :find_message!, only: [:show, :deliveries, :retry, :cancel_hold]

      # GET /api/v2/management/servers/:server_uuid/messages
      def index
        options = build_query_options
        page = [params[:page].to_i, 1].max
        per_page = [[params[:per_page].to_i, 25].max, 100].min
        per_page = 25 if params[:per_page].blank?

        result = @server.message_db.messages_with_pagination(page, options.merge(per_page: per_page))

        messages_data = result[:records].map { |m| message_json(m) }

        meta = {
          page: result[:page],
          per_page: result[:per_page],
          total: result[:total],
          total_pages: result[:total_pages]
        }

        render_success(messages_data, meta: meta)
      end

      # GET /api/v2/management/servers/:server_uuid/messages/:id
      def show
        render_success(message_json(@message, detailed: true))
      end

      # GET /api/v2/management/servers/:server_uuid/messages/:id/deliveries
      def deliveries
        deliveries_data = @message.deliveries.map do |delivery|
          {
            id: delivery.id,
            status: delivery.status,
            details: delivery.details,
            output: delivery.output,
            sent_with_ssl: delivery.sent_with_ssl,
            log_id: delivery.log_id,
            timestamp: delivery.timestamp.iso8601
          }
        end

        render_success(deliveries_data)
      end

      # POST /api/v2/management/servers/:server_uuid/messages/:id/retry
      def retry
        queued_message = @message.queued_message

        if queued_message.nil?
          render_error("NotQueued", "This message is not in the queue")
          return
        end

        queued_message.retry_now
        render_success({
          message: "Message has been queued for retry",
          message_id: @message.id
        })
      end

      # POST /api/v2/management/servers/:server_uuid/messages/:id/cancel_hold
      def cancel_hold
        unless @message.held?
          render_error("NotHeld", "This message is not held")
          return
        end

        @message.cancel_hold
        render_success({
          message: "Hold has been cancelled",
          message_id: @message.id
        })
      end

      # GET /api/v2/management/servers/:server_uuid/queue
      def queue
        queued_messages = @server.queued_messages.includes(:ip_address)
        queued_messages = filter_queue(queued_messages)
        queued_messages = queued_messages.order(created_at: :desc)

        queued_messages, meta = paginate(queued_messages)

        render_success(
          queued_messages.map { |qm| queued_message_json(qm) },
          meta: meta
        )
      end

      private

      def find_message!
        message_id = params[:id] || params[:message_id]
        @message = @server.message_db.message(message_id.to_i)
      rescue Postal::MessageDB::Message::NotFound
        render_error("NotFound", "Message not found", status: :not_found)
      end

      def check_server_access!
        return if current_api_key.super_admin?
        return if current_api_key.can_access_organization?(@server.organization)

        render_error("Forbidden", "You don't have access to this server", status: :forbidden)
      end

      def build_query_options
        options = { order: :timestamp, direction: "DESC" }
        where = {}

        where[:scope] = params[:direction] if params[:direction].present?
        where[:rcpt_to] = params[:to] if params[:to].present?
        where[:mail_from] = params[:from] if params[:from].present?
        where[:status] = params[:status] if params[:status].present?
        where[:held] = true if params[:scope] == "held"
        where[:tag] = params[:tag] if params[:tag].present?

        options[:where] = where if where.any?
        options
      end

      def filter_queue(scope)
        scope = scope.where(domain: params[:domain]) if params[:domain].present?
        scope = scope.where("locked_by IS NOT NULL") if params[:locked] == "true"
        scope = scope.where(locked_by: nil) if params[:locked] == "false"
        scope
      end

      def message_json(message, detailed: false)
        data = {
          id: message.id,
          token: message.token,
          direction: message.scope,
          status: message.status,
          held: message.held?,
          from: message.mail_from,
          to: message.rcpt_to,
          subject: message.subject,
          message_id: message.message_id,
          tag: message.tag,
          timestamp: message.timestamp&.iso8601,
          size: message.size,
          spam_status: message.spam_status,
          spam_score: message.spam_score&.to_f
        }

        if detailed
          data[:domain] = message.domain ? { uuid: message.domain.uuid, name: message.domain.name } : nil
          data[:credential] = message.credential ? { uuid: message.credential.uuid, name: message.credential.name } : nil
          data[:route] = message.route ? { uuid: message.route.uuid, name: message.route.name } : nil

          data[:tracking] = {
            loaded: message.loaded ? Time.zone.at(message.loaded).iso8601 : nil,
            clicked: message.clicked ? Time.zone.at(message.clicked).iso8601 : nil,
            tracked_links: message.tracked_links,
            tracked_images: message.tracked_images
          }

          data[:hold_expiry] = message.hold_expiry&.iso8601

          if message.queued_message
            data[:queue] = {
              locked: message.queued_message.locked_by.present?,
              locked_by: message.queued_message.locked_by,
              retry_after: message.queued_message.retry_after&.iso8601,
              attempts: message.queued_message.attempts
            }
          end

          # Last delivery info
          if message.deliveries.any?
            last_delivery = message.deliveries.last
            data[:last_delivery] = {
              status: last_delivery.status,
              details: last_delivery.details,
              timestamp: last_delivery.timestamp.iso8601
            }
          end
        end

        data
      end

      def queued_message_json(qm)
        {
          id: qm.id,
          message_id: qm.message_id,
          domain: qm.domain,
          locked: qm.locked_by.present?,
          locked_by: qm.locked_by,
          locked_at: qm.locked_at&.iso8601,
          retry_after: qm.retry_after&.iso8601,
          attempts: qm.attempts,
          manual: qm.manual,
          ip_address: qm.ip_address&.ipv4,
          created_at: qm.created_at.iso8601
        }
      end

    end
  end
end
