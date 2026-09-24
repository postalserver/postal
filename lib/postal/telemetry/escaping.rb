# frozen_string_literal: true

module Postal
  module Telemetry
    #
    # Escaping for the wire formats Postal writes. Each method follows the
    # format's own rules rather than a generic "quote it" helper, because the
    # rules differ: Prometheus and Influx disagree on which characters to escape
    # and how.
    #
    module Escaping

      module_function

      #
      # Prometheus text exposition.
      #
      # Label values are the only place arbitrary text appears. Backslash,
      # double quote and newline are escaped, in that order (backslash first so
      # it does not double-escape the others).
      #
      def prometheus_label_value(value)
        value.to_s.gsub("\\") { "\\\\" }.gsub("\"") { "\\\"" }.gsub("\n") { "\\n" }
      end

      #
      # Metric and label names are restricted by the exposition format. Reject
      # anything else rather than emit a payload a scraper will discard.
      #
      def prometheus_metric_name(name)
        name = name.to_s
        unless name.match?(/\A[a-zA-Z_:][a-zA-Z0-9_:]*\z/)
          raise Postal::Error, "Invalid Prometheus metric name #{name.inspect}"
        end

        name
      end

      def prometheus_label_name(name)
        name = name.to_s
        unless name.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)
          raise Postal::Error, "Invalid Prometheus label name #{name.inspect}"
        end

        name
      end

      #
      # InfluxDB line protocol. A backslash escapes spaces and commas in a
      # measurement, and those plus the equals sign in a tag key and value.
      #
      def influx_measurement(value)
        value.to_s.gsub(/[ ,]/) { |character| "\\#{character}" }
      end

      def influx_key(value)
        value.to_s.gsub(/[ ,=]/) { |character| "\\#{character}" }
      end

    end
  end
end
