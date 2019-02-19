module Postal
  module SMTPServer
    # Workers pool
    class WorkersPool
      # Worker pool inicialization
      # @param num_workers[Integer] number of workers
      def initialize(num_workers = 2)
        @num_workers = num_workers < 1 ? 1 : num_workers
        @queue = Queue.new
      end

      # Start workers
      def worker(&block)
        @threads = Array.new @num_workers do
          Thread.new do
            loop do
              item = @queue.pop
              yield(item)
            end
          end
        end
      end

      # add event to queue
      def <<(item)
        @queue << item
      end
    end
  end
end
