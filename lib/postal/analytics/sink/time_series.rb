# frozen_string_literal: true

module Postal
  module Analytics
    module Sink
      #
      # Writes the daily statistics as time series over a text protocol which
      # many stores share (see Postal::Telemetry::Client). The scheme decides
      # the protocol, so the same sink serves VictoriaMetrics, Prometheus,
      # InfluxDB, a vector.dev pipeline, and any other compatible backend.
      #
      # One series per counter per date, timestamped at the date's midnight, so
      # a re-run overwrites the same points rather than duplicating them.
      #
      class TimeSeries

        METRIC = "postal_stats_daily"

        def initialize(url)
          @client = Postal::Telemetry::Client.new(url)
        end

        def write(server_id, permalink, rows)
          @client.write(rows.flat_map { |row| samples_for(server_id, permalink, row) })
          "#{METRIC}{server=\"#{permalink}\",server_id=\"#{server_id}\"}"
        end

        private

        def samples_for(server_id, permalink, row)
          date, *counters = row
          time = time_for(date)
          Counters::NAMES.zip(counters).map do |counter, value|
            Postal::Telemetry::Sample.new(
              METRIC,
              { server: permalink, server_id: server_id.to_s, type: counter },
              value.to_i,
              time
            )
          end
        end

        def time_for(date)
          year, month, day = date.to_s.split("-").map(&:to_i)
          Time.utc(year, month, day).to_i * 1000
        end

      end
    end
  end
end
