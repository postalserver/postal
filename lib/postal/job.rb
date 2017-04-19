require 'nifty/utils/random_string'

module Postal
  class Job
    def initialize(id, params = {})
      @id = id
      @params = params.with_indifferent_access
    end

    def id
      @id
    end

    def params
      @params || {}
    end

    def perform
    end

    def log(text)
      Worker.logger.info "[#{@id}] #{text}"
    end

    def self.queue(queue, params = {})
      job_id = Nifty::Utils::RandomString.generate(:length => 10).upcase
      job_payload = {'params' => params, 'class_name' => self.name, 'id' => job_id, 'queue' => queue}
      Postal::Worker.job_queue(queue).publish(job_payload.to_json, :persistent => false)
      job_id
    end

    def self.perform(params = {})
      new(nil, params).perform
    end
  end
end
