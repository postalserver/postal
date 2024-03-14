# frozen_string_literal: true

module LegacyAPI
  class SendController < BaseController

    ERROR_MESSAGES = {
      "NoRecipients" => "There are no recipients defined to receive this message",
      "NoContent" => "There is no content defined for this e-mail",
      "TooManyToAddresses" => "The maximum number of To addresses has been reached (maximum 50)",
      "TooManyCCAddresses" => "The maximum number of CC addresses has been reached (maximum 50)",
      "TooManyBCCAddresses" => "The maximum number of BCC addresses has been reached (maximum 50)",
      "FromAddressMissing" => "The From address is missing and is required",
      "UnauthenticatedFromAddress" => "The From address is not authorised to send mail from this server",
      "AttachmentMissingName" => "An attachment is missing a name",
      "AttachmentMissingData" => "An attachment is missing data"
    }.freeze

    # Send a message with the given options
    #
    #   URL:            /api/v1/send/message
    #
    #   Parameters:     to              => REQ: An array of emails addresses
    #                   cc              => An array of email addresses to CC
    #                   bcc             => An array of email addresses to BCC
    #                   from            => The name/email to send the email from
    #                   sender          => The name/email of the 'Sender'
    #                   reply_to        => The name/email of the 'Reply-to'
    #                   plain_body      => The plain body
    #                   html_body       => The HTML body
    #                   bounce          => Is this message a bounce?
    #                   tag             => A custom tag to add to the message
    #                   custom_headers  => A hash of custom headers
    #                   attachments     => An array of attachments
    #                                      (name, content_type and data (base64))
    #
    #   Response:       A array of hashes containing message information
    #                   OR an error if there is an issue sending the message
    #
    def message
      attributes = {}
      attributes[:to] = api_params["to"]
      attributes[:cc] = api_params["cc"]
      attributes[:bcc] = api_params["bcc"]
      attributes[:from] = api_params["from"]
      attributes[:sender] = api_params["sender"]
      attributes[:subject] = api_params["subject"]
      attributes[:reply_to] = api_params["reply_to"]
      attributes[:plain_body] = api_params["plain_body"]
      attributes[:html_body] = api_params["html_body"]
      attributes[:bounce] = api_params["bounce"] ? true : false
      attributes[:tag] = api_params["tag"]
      attributes[:custom_headers] = api_params["headers"] if api_params["headers"]
      attributes[:attachments] = []

      (api_params["attachments"] || []).each do |attachment|
        next unless attachment.is_a?(Hash)

        attributes[:attachments] << { name: attachment["name"], content_type: attachment["content_type"], data: attachment["data"], base64: true }
      end

      message = OutgoingMessagePrototype.new(@current_credential.server, request.ip, "api", attributes)
      message.credential = @current_credential
      if message.valid?
        result = message.create_messages
        render_success message_id: message.message_id, messages: result
      else
        render_error message.errors.first, message: ERROR_MESSAGES[message.errors.first]
      end
    end

    # Send a message by providing a raw message
    #
    #   URL:            /api/v1/send/raw
    #
    #   Parameters:     rcpt_to         => REQ: An array of email addresses to send
    #                                      the message to
    #                   mail_from       => REQ: the address to send the email from
    #                   data            => REQ: base64-encoded mail data
    #
    #   Response:       A array of hashes containing message information
    #                   OR an error if there is an issue sending the message
    #
    def raw
      unless api_params["rcpt_to"].is_a?(Array)
        render_parameter_error "`rcpt_to` parameter is required but is missing"
        return
      end

      if api_params["mail_from"].blank?
        render_parameter_error "`mail_from` parameter is required but is missing"
        return
      end

      if api_params["data"].blank?
        render_parameter_error "`data` parameter is required but is missing"
        return
      end

      # Decode the raw message
      raw_message = Base64.decode64(api_params["data"])

      # Parse through mail to get the from/sender headers
      mail = Mail.new(raw_message.split("\r\n\r\n", 2).first)
      from_headers = { "from" => mail.from, "sender" => mail.sender }
      authenticated_domain = @current_credential.server.find_authenticated_domain_from_headers(from_headers)

      # If we're not authenticated, don't continue
      if authenticated_domain.nil?
        render_error "UnauthenticatedFromAddress"
        return
      end

      # Store the result ready to return
      result = { message_id: nil, messages: {} }
      if api_params["rcpt_to"].is_a?(Array)
        api_params["rcpt_to"].uniq.each do |rcpt_to|
          message = @current_credential.server.message_db.new_message
          message.rcpt_to = rcpt_to
          message.mail_from = api_params["mail_from"]
          message.raw_message = raw_message
          message.received_with_ssl = true
          message.scope = "outgoing"
          message.domain_id = authenticated_domain.id
          message.credential_id = @current_credential.id
          message.bounce = api_params["bounce"] ? true : false
          message.save
          result[:message_id] = message.message_id if result[:message_id].nil?
          result[:messages][rcpt_to] = { id: message.id, token: message.token }
        end
      end
      render_success result
    end

  end
end
