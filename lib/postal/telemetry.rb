# frozen_string_literal: true

module Postal
  #
  # The outbound path: emits metrics and events to external observability as
  # they happen, so dashboards outside Postal see activity immediately rather
  # than after a batch extract.
  #
  # Emitting is deliberately cheap and safe: a call only appends to the
  # publisher's in-memory buffer and returns. The background publisher does the
  # network work, and nothing here is allowed to slow down or fail mail.
  #
  # Postal's own live view is Postal::Metrics, which is the inbound path.
  #
  module Telemetry

    class << self

      def enabled?
        !Postal::Config.telemetry.url.to_s.empty?
      end

      #
      # Record one observation of a metric. Returns true when it was accepted
      # for sending. Never raises.
      #
      def record(name, labels = {}, value = 1)
        return false unless enabled?

        publisher.publish(Sample.new(name.to_s, labels_strings(labels), value, now_ms))
        true
      rescue StandardError => e
        logger.warn("[postal] telemetry record failed: #{e.class}: #{e.message}")
        false
      end

      #
      # A convenience for the common case of counting one event.
      #
      def increment(name, labels = {})
        record(name, labels, 1)
      end

      def publisher
        @publisher ||= Publisher.new
      end

      #
      # Send anything buffered and stop the background thread. Used on shutdown
      # and by the tests.
      #
      def shutdown
        @publisher&.stop
        @publisher = nil
      end

      def logger
        defined?(Rails) && Rails.respond_to?(:logger) ? Rails.logger : Logger.new($stderr)
      end

      private

      def labels_strings(labels)
        (labels || {}).to_h { |key, value| [key.to_s, value.to_s] }
      end

      def now_ms
        Time.now.to_i * 1000
      end

    end

  end
end
