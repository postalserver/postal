# frozen_string_literal: true

module MessageDequeuer

  class << self

    def process(message, logger:)
      processor = InitialProcessor.new(message, logger: logger)
      processor.process
    end

  end

end
