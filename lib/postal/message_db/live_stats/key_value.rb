# frozen_string_literal: true

module Postal
  module MessageDB
    class LiveStats

      #
      # Keeps the live statistics in a key-value store speaking the Redis
      # protocol (Valkey, Redis, and other drop-in replacements that implement
      # the same commands). Each type is counted in one-minute buckets which
      # expire once they fall out of the 60 minute window, so nothing needs
      # pruning.
      #
      # Every operation is a single round trip: the counts for a window are read
      # with one MGET, and the counter and its expiry are written in a pipeline.
      #
      class KeyValue

        # One minute buckets only matter for an hour, so expire a little after
        # that to leave room for clock skew between callers.
        EXPIRY = 3600

        class << self

          #
          # Connections are shared across servers, which all use the same store,
          # so a process holds one client per URL rather than one per server.
          #
          def client(url)
            Postal.require_optional_gem("redis-client", group: "redis")
            @clients ||= {}
            @clients[url] ||= RedisClient.config(url: url).new_client
          end

        end

        def initialize(url)
          if url.nil? || url.to_s.empty?
            raise Postal::Error, "A URL must be configured for the Valkey live stats store"
          end

          # redis-client speaks redis://; accept valkey:// as an alias so the
          # scheme can name the store rather than the protocol.
          @url = url.to_s.sub(/\Avalkey:/, "redis:")
        end

        def increment(type)
          minute = current_minute
          redis.pipelined do |pipeline|
            pipeline.call("INCR", key(type, minute))
            pipeline.call("EXPIRE", key(type, minute), EXPIRY)
          end
        end

        def total(minutes, options = {})
          last = current_minute
          keys = options[:types].flat_map do |type|
            ((last - minutes)..last).map { |minute| key(type, minute) }
          end
          return 0 if keys.empty?

          redis.call("MGET", *keys).sum(&:to_i)
        end

        private

        def current_minute
          Time.now.utc.to_i / 60
        end

        def key(type, minute)
          "postal:live_stats:#{type}:#{minute}"
        end

        def redis
          self.class.client(@url)
        end

      end

    end
  end
end
