# frozen_string_literal: true

module Postal
  module RateLimiter
    #
    # Counters held in a store speaking the Redis protocol (Redis, Valkey, and
    # other drop-in replacements implementing the same commands), shared by
    # every worker so that a limit applies to the deployment rather than to
    # each process. Named Shared rather than after one product: the scheme
    # names the topology, and the protocol is what the code depends on.
    #
    # The window starts at the first counted event and does not slide as further
    # events arrive, which is what the in-process store does too: a limit of ten
    # per five minutes means ten from the first one, not ten in whichever five
    # minutes the clock happens to be in. Counting the event, giving the key its
    # lifetime and reading that lifetime back are a single script, so a key
    # cannot be left behind without an expiry if the process dies mid-count.
    #
    class Shared

      # Increment the counter, set the lifetime only when the key is created so
      # the window does not slide, and return both the count and what is left of
      # the window.
      SCRIPT = <<~LUA
        local hits = redis.call('INCR', KEYS[1])
        if hits == 1 then
          redis.call('EXPIRE', KEYS[1], ARGV[1])
        end
        return {hits, redis.call('TTL', KEYS[1])}
      LUA

      def initialize(url)
        @url = url
      end

      def increment(key, limit:, period:)
        hits, ttl = connection.call("EVAL", SCRIPT, 1, key, period)

        Result.new(hits, limit, ttl)
      end

      #
      # Remove the key, and with it the count against it. The key holds the
      # current window alone, so one delete is enough.
      #
      def clear(key)
        connection.call("DEL", key)
        nil
      end

      private

      def connection
        self.class.client(@url)
      end

      class << self

        #
        # One client per URL per process. Workers all count into the same store,
        # so they can share the connection rather than opening one each.
        #
        def client(url)
          @clients ||= {}
          @clients[url] ||= build_client(url)
        end

        private

        def build_client(url)
          require "redis-client"
        rescue LoadError
          raise Error, "The Redis rate limit store requires the optional 'redis' bundle group " \
                       "(redis-client). Enable it with `bundle config set --local with redis`."
        else
          ::RedisClient.config(url: url).new_client
        end

      end

    end
  end
end
