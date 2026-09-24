# frozen_string_literal: true

require "json"

module Postal
  module Metrics
    #
    # Streams metric events as Server-Sent Events. It is deliberately small and
    # takes its event source and output so it can be tested without a socket;
    # the controller gives it the response stream and a subscriber queue.
    #
    class Stream

      def initialize(io, events: nil)
        @io = io
        @events = events || Broadcaster.subscribe
      end

      #
      # Write events until the source is exhausted (a closed queue yields nil) or
      # the client disconnects.
      #
      def run
        loop do
          event = @events.pop
          break if event.nil?

          @io.write("data: #{JSON.generate(event)}\n\n")
        end
      rescue IOError, Errno::EPIPE
        nil
      ensure
        Broadcaster.unsubscribe(@events)
      end

    end
  end
end
