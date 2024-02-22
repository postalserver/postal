# frozen_string_literal: true

module MessageDequeuer
  class Base

    class StopProcessing < StandardError
    end

    attr_reader :queued_message
    attr_reader :logger
    attr_reader :state

    def initialize(queued_message, logger:, state: nil)
      @queued_message = queued_message
      @logger = logger
      @state = state || State.new
    end

    def process
      raise NotImplemented
    end

    class << self

      def process(message, **kwargs)
        new(message, **kwargs).process
      end

    end

    private

    def stop_processing
      raise StopProcessing
    end

    def catch_stops
      yield if block_given?
      true
    rescue StopProcessing
      false
    end

    def remove_from_queue
      @queued_message.destroy
    end

    def create_delivery(type, **kwargs)
      @queued_message.message.create_delivery(type, **kwargs)
    end

    def log(text, **tags)
      logger.info text, **tags
    end

    def increment_live_stats
      queued_message.message.database.live_stats.increment(queued_message.message.scope)
    end

    def hold_if_server_development_mode
      return if queued_message.manual?
      return unless queued_message.server.mode == "Development"

      log "server is in development mode, holding"
      create_delivery "Held", details: "Server is in development mode."
      remove_from_queue
      stop_processing
    end

    def log_sender_result
      log_details = @result.details

      if @additional_delivery_details
        log_details += "." unless log_details =~ /\.\z/
        log_details += " "
        log_details += @additional_delivery_details
      end

      create_delivery @result.type, details: log_details,
                                    output: @result.output&.strip,
                                    sent_with_ssl: @result.secure,
                                    log_id: @result.log_id,
                                    time: @result.time
    end

    def handle_exception(exception)
      log "internal error: #{exception.class}: #{exception.message}"
      exception.backtrace.each { |line| log(line) }

      queued_message.retry_later unless queued_message.destroyed?
      log "message requeued for trying later, at #{queued_message.retry_after}"

      if defined?(Sentry)
        Sentry.capture_exception(exception, extra: {
          server_id: queued_message.server_id,
          queued_message_id: queued_message.message_id
        })
      end

      queued_message.message&.create_delivery("Error",
                                              details: "An internal error occurred while sending " \
                                                       "this message. This message will be retried " \
                                                       "automatically.",
                                              output: "#{exception.class}: #{exception.message}")
    end

  end
end
