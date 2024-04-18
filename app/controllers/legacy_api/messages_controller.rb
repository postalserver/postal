# frozen_string_literal: true

module LegacyAPI
  class MessagesController < BaseController

    # Returns details about a given message
    #
    #   URL:            /api/v1/messages/message
    #
    #   Parameters:     id              => REQ: The ID of the message
    #                   _expansions     => An array of types of details t
    #                                      to return
    #
    #   Response:       A hash containing message information
    #                   OR an error if the message does not exist.
    #
    def message
      if api_params["id"].blank?
        render_parameter_error "`id` parameter is required but is missing"
        return
      end

      message = @current_credential.server.message(api_params["id"])
      message_hash = { id: message.id, token: message.token }
      expansions = api_params["_expansions"]

      if expansions == true || (expansions.is_a?(Array) && expansions.include?("status"))
        message_hash[:status] = {
          status: message.status,
          last_delivery_attempt: message.last_delivery_attempt&.to_f,
          held: message.held,
          hold_expiry: message.hold_expiry&.to_f
        }
      end

      if expansions == true || (expansions.is_a?(Array) && expansions.include?("details"))
        message_hash[:details] = {
          rcpt_to: message.rcpt_to,
          mail_from: message.mail_from,
          subject: message.subject,
          message_id: message.message_id,
          timestamp: message.timestamp.to_f,
          direction: message.scope,
          size: message.size,
          bounce: message.bounce,
          bounce_for_id: message.bounce_for_id,
          tag: message.tag,
          received_with_ssl: message.received_with_ssl
        }
      end

      if expansions == true || (expansions.is_a?(Array) && expansions.include?("inspection"))
        message_hash[:inspection] = {
          inspected: message.inspected,
          spam: message.spam,
          spam_score: message.spam_score.to_f,
          threat: message.threat,
          threat_details: message.threat_details
        }
      end

      if expansions == true || (expansions.is_a?(Array) && expansions.include?("plain_body"))
        message_hash[:plain_body] = message.plain_body
      end

      if expansions == true || (expansions.is_a?(Array) && expansions.include?("html_body"))
        message_hash[:html_body] = message.html_body
      end

      if expansions == true || (expansions.is_a?(Array) && expansions.include?("attachments"))
        message_hash[:attachments] = message.attachments.map do |attachment|
          {
            filename: attachment.filename.to_s,
            content_type: attachment.mime_type,
            data: Base64.encode64(attachment.body.to_s),
            size: attachment.body.to_s.bytesize,
            hash: Digest::SHA1.hexdigest(attachment.body.to_s)
          }
        end
      end

      if expansions == true || (expansions.is_a?(Array) && expansions.include?("headers"))
        message_hash[:headers] = message.headers
      end

      if expansions == true || (expansions.is_a?(Array) && expansions.include?("raw_message"))
        message_hash[:raw_message] = Base64.encode64(message.raw_message)
      end

      if expansions == true || (expansions.is_a?(Array) && expansions.include?("activity_entries"))
        message_hash[:activity_entries] = {
          loads: message.loads,
          clicks: message.clicks
        }
      end

      render_success message_hash
    rescue Postal::MessageDB::Message::NotFound
      render_error "MessageNotFound",
                   message: "No message found matching provided ID",
                   id: api_params["id"]
    end

    # Returns all the deliveries for a given message
    #
    #   URL:            /api/v1/messages/deliveries
    #
    #   Parameters:     id              => REQ: The ID of the message
    #
    #   Response:       A array of hashes containing delivery information
    #                   OR an error if the message does not exist.
    #
    def deliveries
      if api_params["id"].blank?
        render_parameter_error "`id` parameter is required but is missing"
        return
      end

      message = @current_credential.server.message(api_params["id"])
      deliveries = message.deliveries.map do |d|
        {
          id: d.id,
          status: d.status,
          details: d.details,
          output: d.output&.strip,
          sent_with_ssl: d.sent_with_ssl,
          log_id: d.log_id,
          time: d.time&.to_f,
          timestamp: d.timestamp.to_f
        }
      end
      render_success deliveries
    rescue Postal::MessageDB::Message::NotFound
      render_error "MessageNotFound",
                   message: "No message found matching provided ID",
                   id: api_params["id"]
    end

  end
end
