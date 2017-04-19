module Postal
  class MessageRequeuer

    def run
      Signal.trap("INT")  { @running ? @exit = true : Process.exit(0) }
      Signal.trap("TERM") { @running ? @exit = true : Process.exit(0) }

      log "Running message requeuer..."
      loop do
        @running = true
        QueuedMessage.requeue_all
        @running = false
        check_exit
        sleep 5
      end
    end

    private

    def log(text)
      Postal.logger_for(:message_requeuer).info text
    end

    def check_exit
      if @exit
        log "Exiting"
        Process.exit(0)
      end
    end

  end
end
