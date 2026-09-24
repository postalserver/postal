# frozen_string_literal: true

require "uri"

module Postal
  module MessageDB
    #
    # The live statistics shown on a server's dashboard: the number of messages
    # received and sent in each of the last 60 minutes.
    #
    # The counts are kept in the message database by default. The scheme of
    # live_stats.url selects another store: an in-memory one (Valkey, Redis, or
    # Aerospike) to take the write load off the database, or a
    # Prometheus-compatible time-series store which can also be read by the
    # dashboards.
    #
    class LiveStats

      # Schemes which record the statistics as time series over a text protocol.
      TIME_SERIES_SCHEMES = %w[prometheus influx json].freeze

      # The metric the message counters are recorded under in a time-series
      # store.
      MESSAGE_METRIC = "postal_messages_total"

      class << self

        #
        # The store scheme, with any transport stripped, so
        # "prometheus+http://…" is "prometheus".
        #
        def scheme
          URI.parse(Postal::Config.live_stats.url.to_s).scheme.to_s.split("+").first
        end

        def time_series?
          TIME_SERIES_SCHEMES.include?(scheme)
        end

      end

      def initialize(database)
        @database = database
      end

      #
      # Increment the live stats by one for the current minute.
      #
      def increment(type)
        if self.class.time_series?
          Postal::Metrics.record(MESSAGE_METRIC, { "type" => type.to_s }, 1)
        else
          store.increment(type)
        end
      end

      #
      # Return the total number of messages for the last few minutes.
      #
      def total(minutes, options = {})
        if minutes > 60
          raise Postal::Error, "Live stats can only return data for the last 60 minutes."
        end

        options[:types] ||= [:incoming, :outgoing]
        raise Postal::Error, "You must provide at least one type to return" if options[:types].empty?

        if self.class.time_series?
          types = options[:types].map(&:to_s)
          Postal::Metrics.query(MESSAGE_METRIC, { "type" => types }, window: minutes.to_i * 60).to_i
        else
          store.total(minutes, options)
        end
      end

      private

      #
      # The store for the database and key-value schemes. Time-series schemes
      # are served by Postal::Metrics, which owns that one store.
      #
      def store
        @store ||= build_store
      end

      def build_store
        uri = URI.parse(Postal::Config.live_stats.url.to_s)
        case self.class.scheme
        when "", "mysql"
          Database.new(@database)
        when "valkey", "redis"
          KeyValue.new(uri.to_s)
        when "aerospike"
          Aerospike.new(uri.to_s)
        else
          raise Postal::Error, "Unknown live stats scheme '#{self.class.scheme}'"
        end
      end

    end
  end
end
