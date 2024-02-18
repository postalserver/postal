# frozen_string_literal: true

class SleepJob < Postal::Job

  def perform
    sleep 5
  end

end
