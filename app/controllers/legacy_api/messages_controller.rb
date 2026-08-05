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
      message = find_message
      return if performed?

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
      message = find_message
      return if performed?

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

    private

    # Look up the message referenced by the request's `id` parameter.
    #
    # The legacy API only ever identifies a message by its integer ID. The
    # request body is parsed as JSON, so without validation a JSON object or
    # array supplied for `id` would arrive as a Ruby Hash/Array and be passed
    # straight through to the message database as a raw set of SQL conditions.
    # We therefore reject anything that is not a simple scalar before it can
    # reach the database and coerce the value to an integer ID.
    #
    # Renders an error and returns nil when the parameter is missing or is not
    # a scalar; otherwise returns the matched message (raising NotFound when no
    # message matches, which the actions rescue).
    #
    # @return [Postal::MessageDB::Message, nil]
    def find_message
      id = api_params["id"]

      if id.blank?
        render_parameter_error "`id` parameter is required but is missing"
        return
      end

      unless id.is_a?(String) || id.is_a?(Integer)
        render_parameter_error "`id` parameter must be a string or integer"
        return
      end

      @current_credential.server.message(id.to_i)
    end

  end
end
