# frozen_string_literal: true

module Postal
  #
  # The inbound view of Postal's own statistics, as the dashboard sees it.
  # Metrics are recorded to a fast store as messages flow, read straight back
  # from it, and published to subscribers so the dashboard can react without
  # polling. The database remains the source of truth.
  #
  # Pushing the same activity to external observability is Postal::Telemetry,
  # which is the outbound path.
  #
  module Metrics

    class << self

      def enabled?
        Postal::MessageDB::LiveStats.time_series?
      end

      #
      # Record a value against a metric. Never raises: a metrics write must not
      # slow down or fail message processing.
      #
      def record(name, labels = {}, value = 1)
        return false unless enabled?

        store.record(name, labels, value)
        Broadcaster.publish(name, labels, value)
        true
      rescue StandardError => e
        Rails.logger.warn("[postal] metrics record failed: #{e.class}: #{e.message}")
        false
      end

      #
      # The value of a metric over the configured window, or nil when the live
      # metrics are disabled.
      #
      def query(name, labels = {}, window: nil)
        return nil unless enabled?

        store.query(name, labels, window: window || Postal::Config.live_stats.window)
      end

      def store
        @store ||= Store.build
      end

      def reset!
        @store = nil
        Broadcaster.reset!
      end

    end

  end
end
