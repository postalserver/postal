# frozen_string_literal: true

module Postal
  module Telemetry
    #
    # Buffers samples and writes them in batches from one background thread.
    #
    # The buffer is bounded: when it is full the oldest sample is dropped and
    # counted, so a slow or unreachable backend can never grow Postal's memory
    # or apply backpressure to mail. Every failure is logged and swallowed.
    #
    class Publisher

      attr_reader :dropped

      def initialize(client: nil, logger: nil)
        @client = client || Client.new(Postal::Config.telemetry.url)
        @logger = logger
        @interval = Postal::Config.telemetry.interval.to_f
        @batch_size = Postal::Config.telemetry.batch_size.to_i
        @queue_size = Postal::Config.telemetry.queue_size.to_i
        @queue = Queue.new
        @dropped = 0
        @mutex = Mutex.new
        @running = true
        @thread = Thread.new { loop_flushing }
      end

      #
      # Buffer a sample. Returns immediately; never blocks on the network.
      #
      def publish(sample)
        @mutex.synchronize do
          if @queue.size >= @queue_size
            @queue.pop
            @dropped += 1
          end
          @queue << sample
        end
        true
      end

      #
      # Write everything currently buffered, in batches.
      #
      def flush
        written = 0
        loop do
          batch = drain
          break if batch.empty?

          written += write(batch)
        end
        written
      end

      def stop
        @running = false
        @thread.wakeup if @thread&.alive?
        @thread&.join(5)
      rescue StandardError
        nil
      end

      private

      def loop_flushing
        while @running
          sleep @interval
          flush
        end
      rescue StandardError => e
        log "publisher stopped: #{e.class}: #{e.message}"
      end

      def drain
        samples = []
        @mutex.synchronize do
          samples << @queue.pop until @queue.empty? || samples.size >= @batch_size
        end
        samples
      end

      def write(samples)
        @client.write(samples)
      rescue StandardError => e
        log "write failed: #{e.class}: #{e.message}"
        0
      end

      def log(message)
        (@logger || Postal::Telemetry.logger).warn("[postal] telemetry #{message}")
      end

    end
  end
end
