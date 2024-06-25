# frozen_string_literal: true

class ApplicationScheduledTask

  def initialize(logger:)
    @logger = logger
  end

  def call
    raise NotImplementedError
  end

  attr_reader :logger

  class << self

    def next_run_after
      quarter_past_each_hour
    end

    private

    def quarter_past_each_hour
      time = Time.current
      time = time.change(min: 15, sec: 0)
      time += 1.hour if time < Time.current
      time
    end

    def quarter_to_each_hour
      time = Time.current
      time = time.change(min: 45, sec: 0)
      time += 1.hour if time < Time.current
      time
    end

    def three_am
      time = Time.current
      time = time.change(hour: 3, min: 0, sec: 0)
      time += 1.day if time < Time.current
      time
    end

  end

end
