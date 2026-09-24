# frozen_string_literal: true

module Postal
  module RateLimiter
    #
    # Counters held in this process. Exact for a single worker and requiring no
    # configuration, which is the right default for a deployment with one SMTP
    # process. With more than one, each gets its own allowance, so a shared
    # store is the correct choice there.
    #
    class Memory

      # Expired keys are only swept once the table has grown beyond this, so the
      # common path stays a single hash lookup.
      PRUNE_THRESHOLD = 10_000

      def initialize
        @counters = {}
        @mutex = Mutex.new
      end

      def increment(key, limit:, period:)
        now = Time.now.to_i
        @mutex.synchronize do
          prune(now) if @counters.size > PRUNE_THRESHOLD

          hits, expires_at = @counters[key]
          if expires_at && expires_at > now
            hits += 1
          else
            hits = 1
            expires_at = now + period
          end
          @counters[key] = [hits, expires_at]

          Result.new(hits, limit, expires_at - now)
        end
      end

      def clear(key)
        @mutex.synchronize { @counters.delete(key) }
        nil
      end

      private

      def prune(now)
        @counters.delete_if { |_key, (_hits, expires_at)| expires_at <= now }
      end

    end
  end
end
