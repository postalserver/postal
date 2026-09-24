# frozen_string_literal: true

module Postal
  module Metrics
    #
    # A tiny in-process pub/sub used to stream metric changes to subscribers
    # (the SSE endpoint). Each subscriber gets a bounded queue, so a slow reader
    # cannot grow without limit; dropping an event is acceptable for a live view.
    #
    module Broadcaster

      MAX_QUEUE = 100

      class << self

        def subscribe
          queue = Queue.new
          mutex.synchronize { subscribers << queue }
          queue
        end

        def unsubscribe(queue)
          mutex.synchronize { subscribers.delete(queue) }
        end

        def publish(name, labels, value)
          event = { "name" => name, "labels" => labels, "value" => value, "time" => Time.now.to_i }
          mutex.synchronize do
            subscribers.each { |queue| queue << event if queue.size < MAX_QUEUE }
          end
        end

        def subscribers
          @subscribers ||= []
        end

        def reset!
          mutex.synchronize { subscribers.clear }
        end

        private

        def mutex
          @mutex ||= Mutex.new
        end

      end

    end
  end
end
