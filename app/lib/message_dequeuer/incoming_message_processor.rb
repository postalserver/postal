# frozen_string_literal: true

module MessageDequeuer
  class IncomingMessageProcessor < Base

    attr_reader :route

    def process
      log "message is incoming"

      catch_stops do
        handle_bounces
        increment_live_stats
        inspect_message
        fail_if_spam
        hold_if_server_development_mode
        find_route
        hold_or_reject_spam
        accept_mail_without_endpoints
        hold_messages
        bounce_messages
        send_message_to_sender
        send_bounce_on_hard_fail
        log_sender_result
        finish_processing
      end
    rescue StandardError => e
      handle_exception(e)
    end

    private

    def handle_bounces
      return unless queued_message.message.bounce

      log "message is a bounce"
      original_messages = queued_message.message.original_messages
      unless original_messages.empty?
        queued_message.message.original_messages.each do |orig_msg|
          queued_message.message.update(bounce_for_id: orig_msg.id, domain_id: orig_msg.domain_id)
          create_delivery "Processed", details: "This has been detected as a bounce message for <msg:#{orig_msg.id}>."
          orig_msg.bounce!(queued_message.message)
          log "bounce linked with message #{orig_msg.id}"
        end
        remove_from_queue
        stop_processing
      end

      # This message was sent to the return path but hasn't been matched
      # to an original message. If we have a route for this, route it
      # otherwise we'll drop at this point.
      return unless queued_message.message.route_id.nil?

      log "no source messages found, hard failing"
      create_delivery "HardFail", details: "This message was a bounce but we couldn't link it with any outgoing message and there was no route for it."
      remove_from_queue
      stop_processing
    end

    def inspect_message
      return if queued_message.message.inspected

      log "inspecting message"
      queued_message.message.inspect_message
      return unless queued_message.message.inspected

      is_spam = queued_message.message.spam_score > queued_message.server.spam_threshold
      if is_spam
        queued_message.message.update(spam: true)
        log "message is spam (scored #{queued_message.message.spam_score}, threshold is #{queued_message.server.spam_threshold})"
      end

      queued_message.message.append_headers(
        "X-Postal-Spam: #{queued_message.message.spam ? 'yes' : 'no'}",
        "X-Postal-Spam-Threshold: #{queued_message.server.spam_threshold}",
        "X-Postal-Spam-Score: #{queued_message.message.spam_score}",
        "X-Postal-Threat: #{queued_message.message.threat ? 'yes' : 'no'}"
      )
      log "message inspected, headers added", spam: queued_message.message.spam?, spam_score: queued_message.message.spam_score, threat: queued_message.message.threat?
    end

    def fail_if_spam
      return if queued_message.message.spam_score < queued_message.server.spam_failure_threshold

      log "message has a spam score higher than the server's maxmimum, hard failing", server_threshold: queued_message.server.spam_failure_threshold
      create_delivery "HardFail",
                      details: "Message's spam score is higher than the failure threshold for this server. " \
                               "Threshold is currently #{queued_message.server.spam_failure_threshold}."
      remove_from_queue
      stop_processing
    end

    def find_route
      @route = queued_message.message.route
      return if @route

      log "no route and/or endpoint available for processing, hard failing"
      create_delivery "HardFail", details: "Message does not have a route and/or endpoint available for delivery."
      remove_from_queue
      stop_processing
    end

    def hold_or_reject_spam
      return unless queued_message.message.spam
      return if queued_message.manual?

      case @route.spam_mode
      when "Quarantine"
        log "message is spam and route says to quarantine spam message, holding"
        create_delivery "Held", details: "Message placed into quarantine."
      when "Fail"
        log "message is spam and route says to fail spam message, hard failing"
        create_delivery "HardFail", details: "Message is spam and the route specifies it should be failed."
      else
        return
      end

      remove_from_queue
      stop_processing
    end

    def accept_mail_without_endpoints
      return unless @route.mode == "Accept"

      log "route says to accept without endpoint, marking as processed"
      create_delivery "Processed", details: "Message has been accepted but not sent to any endpoints."
      remove_from_queue
      stop_processing
    end

    def hold_messages
      return unless @route.mode == "Hold"

      if queued_message.manual?
        log "route says to hold and message was queued manually, marking as processed"
        create_delivery "Processed", details: "Message has been processed."
      else
        log "route says to hold, marking as held"
        create_delivery "Held", details: "Message has been accepted but not sent to any endpoints."
      end

      remove_from_queue
      stop_processing
    end

    def bounce_messages
      return unless route.mode == "Bounce" || route.mode == "Reject"

      log "route says to bounce, hard failing and sending bounce"

      if id = queued_message.send_bounce
        log "bounce sent with id #{id}"
        create_delivery "HardFail", details: "Message has been bounced because the route asks for this. See message <msg:#{id}>"
      end

      remove_from_queue
      stop_processing
    end

    def send_message_to_sender
      @result = @state.send_result
      return if @result

      case queued_message.message.endpoint
      when SMTPEndpoint
        sender = @state.sender_for(SMTPSender, queued_message.message.recipient_domain, nil, servers: [queued_message.message.endpoint.to_smtp_client_server])
      when HTTPEndpoint
        sender = @state.sender_for(HTTPSender, queued_message.message.endpoint)
      when AddressEndpoint
        sender = @state.sender_for(SMTPSender, queued_message.message.endpoint.domain, nil, rcpt_to: queued_message.message.endpoint.address)
      else
        log "invalid endpoint for route (#{queued_message.message.endpoint_type})"
        create_delivery "HardFail", details: "Invalid endpoint for route."
        remove_from_queue
        stop_processing
      end

      @result = sender.send_message(queued_message.message)
      return unless @result.connect_error

      @state.send_result = @result
    end

    def send_bounce_on_hard_fail
      return unless @result.type == "HardFail"

      if @result.suppress_bounce
        log "suppressing bounce message after hard fail"
        return
      end

      return unless queued_message.message.send_bounces?

      log "sending a bounce because message hard failed"
      return unless bounce_id = queued_message.send_bounce

      @additional_delivery_details = "Sent bounce message to sender (see message <msg:#{bounce_id}>)"
    end

    def finish_processing
      if @result.retry
        queued_message.retry_later(@result.retry.is_a?(Integer) ? @result.retry : nil)
        log "message requeued for trying later, at #{queued_message.retry_after}"
        queued_message.allocate_ip_address
        queued_message.update_column(:ip_address_id, queued_message.ip_address&.id)
        stop_processing
      end

      log "message processing completed"
      queued_message.message.endpoint.mark_as_used
      remove_from_queue
    end

  end
end
