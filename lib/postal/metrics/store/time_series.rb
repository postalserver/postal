# frozen_string_literal: true

module Postal
  module Metrics
    module Store
      #
      # Keeps the live statistics as time series over the Prometheus text
      # protocol, so the same store serves the live counters and the longer
      # history, both queryable with PromQL/MetricsQL. It is the store that
      # live_stats.url selects for the prometheus scheme; the influx and json
      # schemes are write-only and cannot be read back here.
      #
      class TimeSeries

        def initialize
          @client = Postal::Telemetry::Client.new(Postal::Config.live_stats.url)
        end

        def record(name, labels, value)
          @client.write([Postal::Telemetry::Sample.new(name, labels, value, Time.now.to_i * 1000)])
        end

        def query(name, labels, window:)
          selector = "#{name}#{label_set(labels)}"
          data = @client.query("sum(sum_over_time(#{selector}[#{window.to_i}s]))", time: Time.now)
          (data["result"] || []).sum { |entry| entry["value"][1].to_f }
        end

        private

        #
        # A label set for the selector. A label whose value is an array matches
        # any of them, so { "type" => %w[incoming outgoing] } becomes
        # type=~"incoming|outgoing".
        #
        def label_set(labels)
          return "" if labels.nil? || labels.empty?

          pairs = labels.map do |key, value|
            name = Postal::Telemetry::Escaping.prometheus_label_name(key)
            if value.is_a?(Array)
              "#{name}=~\"#{alternation(value)}\""
            else
              "#{name}=\"#{Postal::Telemetry::Escaping.prometheus_label_value(value)}\""
            end
          end
          "{#{pairs.join(',')}}"
        end

        def alternation(values)
          values.map { |value| Postal::Telemetry::Escaping.prometheus_label_value(value) }.join("|")
        end

      end
    end
  end
end
