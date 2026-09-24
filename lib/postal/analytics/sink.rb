# frozen_string_literal: true

module Postal
  module Analytics
    #
    # A sink is the destination for an analytics extract. The scheme of
    # analytics.url selects one: DuckDB (embedded), ClickHouse, or a
    # time-series protocol (prometheus/influx/json) for any compatible store:
    # VictoriaMetrics, Prometheus, InfluxDB, a vector.dev http_server, and so on.
    #
    module Sink

      class << self

        #
        # Build the sink described by analytics.url.
        #
        def build
          url = Postal::Config.analytics.url.to_s
          if url.empty?
            raise Postal::Error, "analytics.url must be set to write an analytics extract"
          end

          case protocol(url)
          when "duckdb"
            DuckDB.new(url)
          when "clickhouse"
            ClickHouse.new(url)
          when "prometheus", "influx", "json"
            TimeSeries.new(url)
          else
            raise Postal::Error, "Unknown analytics scheme '#{protocol(url)}'"
          end
        end

        #
        # The scheme up to any transport, so "prometheus+http://…" is
        # "prometheus" and "duckdb:///…" is "duckdb".
        #
        def protocol(url)
          url.to_s.split(":", 2).first.to_s.split("+").first
        end

      end

    end
  end
end
