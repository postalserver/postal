# frozen_string_literal: true

module MessageDequeuer
  class OutgoingMessageProcessor < Base

    def process
      catch_stops do
        check_domain
        check_rcpt_to
        add_tag
        hold_if_credential_is_set_to_hold
        hold_if_recipient_on_suppression_list
        parse_content
        inspect_message
        fail_if_spam
        add_outgoing_headers
        check_send_limits
        increment_live_stats
        hold_if_server_development_mode
        send_message_to_sender
        add_recipient_to_suppression_list_on_too_many_hard_fails
        remove_recipient_from_suppression_list_on_success
        log_sender_result
        finish_processing
      end
    rescue StandardError => e
      handle_exception(e)
    end

    private

    def check_domain
      return if queued_message.message.domain

      log "message has no domain, hard failing"
      create_delivery "HardFail", details: "Message's domain no longer exist"
      remove_from_queue
      stop_processing
    end

    def check_rcpt_to
      return unless queued_message.message.rcpt_to.blank?

      log "message has no 'to' address, hard failing"
      create_delivery "HardFail", details: "Message doesn't have an RCPT to"
      remove_from_queue
      stop_processing
    end

    def add_tag
      return if queued_message.message.tag
      return unless tag = queued_message.message.headers["x-postal-tag"]

      log "added tag: #{tag.last}"
      queued_message.message.update(tag: tag.last)
    end

    def hold_if_credential_is_set_to_hold
      return if queued_message.manual?
      return if queued_message.message.credential.nil?
      return unless queued_message.message.credential.hold?

      log "credential wants us to hold messages, holding"
      create_delivery "Held", details: "Credential is configured to hold all messages authenticated by it."
      remove_from_queue
      stop_processing
    end

    def hold_if_recipient_on_suppression_list
      return if queued_message.manual?
      return unless sl = queued_message.server.message_db.suppression_list.get(:recipient, queued_message.message.rcpt_to)

      log "recipient is on the suppression list, holding"
      create_delivery "Held", details: "Recipient (#{queued_message.message.rcpt_to}) is on the suppression list (reason: #{sl['reason']})"
      remove_from_queue
      stop_processing
    end

    def parse_content
      return unless queued_message.message.should_parse?

      log "parsing message content as it hasn't been parsed before"
      queued_message.message.parse_content
    end

    def inspect_message
      return if queued_message.message.inspected
      return unless queued_message.server.outbound_spam_threshold

      log "inspecting message"
      queued_message.message.inspect_message
      return unless queued_message.message.inspected

      if queued_message.message.spam_score >= queued_message.server.outbound_spam_threshold
        queued_message.message.update(spam: true)
      end

      log "message inspected successfully", spam: queued_message.message.spam?, spam_score: queued_message.message.spam_score
    end

    def fail_if_spam
      return unless queued_message.message.spam

      log "message is spam (#{queued_message.message.spam_score}), hard failing", server_threshold: queued_message.server.outbound_spam_threshold
      create_delivery "HardFail",
                      details: "Message is likely spam. Threshold is #{queued_message.server.outbound_spam_threshold} and " \
                               "the message scored #{queued_message.message.spam_score}."
      remove_from_queue
      stop_processing
    end

    def add_outgoing_headers
      return if queued_message.message.has_outgoing_headers?

      queued_message.message.add_outgoing_headers
    end

    def check_send_limits
      if queued_message.server.send_limit_exceeded?
        # If we're over the limit, we're going to be holding this message
        log "server send limit has been exceeded, holding", send_limit: queued_message.server.send_limit
        queued_message.server.update_columns(send_limit_exceeded_at: Time.now, send_limit_approaching_at: nil)
        create_delivery "Held", details: "Message held because send limit (#{queued_message.server.send_limit}) has been reached."
        remove_from_queue
        stop_processing
      elsif queued_message.server.send_limit_approaching?
        # If we're approaching the limit, just say we are but continue to process the message
        queued_message.server.update_columns(send_limit_approaching_at: Time.now, send_limit_exceeded_at: nil)
      else
        queued_message.server.update_columns(send_limit_approaching_at: nil, send_limit_exceeded_at: nil)
      end
    end

    def send_message_to_sender
      @result = @state.send_result
      return if @result

      sender = @state.sender_for(SMTPSender,
                                 queued_message.message.recipient_domain,
                                 queued_message.ip_address)

      @result = sender.send_message(queued_message.message)
      return unless @result.connect_error

      @state.send_result = @result
    end

    def add_recipient_to_suppression_list_on_too_many_hard_fails
      return unless @result.type == "HardFail"

      recent_hard_fails = queued_message.server.message_db.select(:messages,
                                                                  where: {
                                                                    rcpt_to: queued_message.message.rcpt_to,
                                                                    status: "HardFail",
                                                                    timestamp: { greater_than: 24.hours.ago.to_f }
                                                                  },
                                                                  count: true)
      return if recent_hard_fails < 1

      added = queued_message.server.message_db.suppression_list.add(:recipient, queued_message.message.rcpt_to,
                                                                    reason: "too many hard fails")
      return unless added

      log "Added #{queued_message.message.rcpt_to} to suppression list because #{recent_hard_fails} hard fails in 24 hours"
      @additional_delivery_details = "Recipient added to suppression list (too many hard fails)"
    end

    def remove_recipient_from_suppression_list_on_success
      return unless @result.type == "Sent"

      removed = queued_message.server.message_db.suppression_list.remove(:recipient, queued_message.message.rcpt_to)
      return unless removed

      log "removed #{queued_message.message.rcpt_to} from suppression list"
      @additional_delivery_details = "Recipient removed from suppression list"
    end

    def finish_processing
      if @result.retry
        queued_message.retry_later(@result.retry.is_a?(Integer) ? @result.retry : nil)
        log "message requeued for trying later", retry_after: queued_message.retry_after
        stop_processing
      end

      log "message processing complete"
      remove_from_queue
    end

  end
end
