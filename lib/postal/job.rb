require "nifty/utils/random_string"

module Postal
  class Job

    def initialize(id, params = {})
      @id = id
      @params = params
      on_initialize
    end

    attr_reader :id

    def params
      @params || {}
    end

    def on_initialize
      # Called whenever the class is initialized. Can be overriden.
    end

    def on_error(exception)
      # Called if there's an exception while processing the perform block.
      # Receives the exception.
    end

    def perform
    end

    def log(text)
      Worker.logger.info "[#{@id}] #{text}"
    end

    def self.queue(queue, params = {})
      job_id = Nifty::Utils::RandomString.generate(length: 10).upcase
      job_payload = { "params" => params, "class_name" => name, "id" => job_id, "queue" => queue }
      Postal::Worker.job_queue(queue).publish(job_payload.to_json, persistent: false)
      job_id
    end

  end
end
