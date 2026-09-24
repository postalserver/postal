# frozen_string_literal: true

require "uri"

module Postal
  module MessageDB
    class LiveStats

      #
      # Keeps the live statistics in an Aerospike store. Each type is counted in
      # one-minute buckets which expire once they fall out of the 60 minute
      # window, so nothing needs pruning.
      #
      class Aerospike

        EXPIRY = 3600
        BIN = "count"

        def initialize(url)
          uri = URI.parse(url.to_s)
          if uri.host.nil? || uri.host.empty?
            raise Postal::Error, "live_stats.url must name an Aerospike host"
          end

          @hosts = "#{uri.host}:#{uri.port || 3000}"
          namespace, set = uri.path.to_s.delete_prefix("/").split("/", 2)
          @namespace = namespace.to_s.empty? ? "test" : namespace
          @set = set.to_s.empty? ? "postal_live_stats" : set
        end

        #
        # Increment the counter for the current minute. A single operate call
        # adds to the bin and (re)sets its TTL.
        #
        def increment(type)
          client.operate(key(type, current_minute),
                         [::Aerospike::Operation.add(::Aerospike::Bin.new(BIN, 1))],
                         ttl: EXPIRY)
        end

        #
        # Sum the counters for the last few minutes. Read in one batch so the
        # call is a single round trip regardless of the window.
        #
        def total(minutes, options = {})
          last = current_minute
          first = last - minutes
          keys = options[:types].flat_map do |type|
            (first..last).map { |minute| key(type, minute) }
          end

          client.batch_get(keys).sum do |record|
            record&.bins ? record.bins[BIN].to_i : 0
          end
        end

        private

        def current_minute
          Time.now.utc.to_i / 60
        end

        def key(type, minute)
          ::Aerospike::Key.new(@namespace, @set, "live_stats:#{type}:#{minute}")
        end

        def client
          self.class.client(@hosts)
        end

        class << self

          #
          # One Aerospike client per host list per process, shared across
          # servers.
          #
          def client(hosts)
            Postal.require_optional_gem("aerospike", group: "aerospike")
            @clients ||= {}
            @clients[hosts] ||= ::Aerospike::Client.new(hosts)
          end

        end

      end

    end
  end
end
