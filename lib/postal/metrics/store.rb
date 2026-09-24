# frozen_string_literal: true

module Postal
  module Metrics
    #
    # The store the live metrics are recorded to and read from. It is the same
    # time-series store the live counters use, so it is only available when
    # live_stats.url names a Prometheus-compatible time-series store.
    #
    module Store

      def self.build
        unless Postal::MessageDB::LiveStats.time_series?
          raise Postal::Error, "The live metrics store needs a time-series live_stats.url " \
                               "(prometheus, influx or json)"
        end

        TimeSeries.new
      end

    end
  end
end
