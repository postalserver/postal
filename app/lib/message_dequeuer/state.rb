# frozen_string_literal: true

module MessageDequeuer
  class State

    attr_accessor :send_result

    def sender_for(klass, *args)
      @cached_senders ||= {}
      @cached_senders[[klass, args]] ||= begin
        klass_instance = klass.new(*args)
        klass_instance.start
        klass_instance
      end
    end

    def finished
      @cached_senders&.each_value do |sender|
        sender.finish
      rescue StandardError
        false
      end
    end

  end
end
