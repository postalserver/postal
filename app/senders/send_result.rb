# frozen_string_literal: true

class SendResult

  attr_accessor :type
  attr_accessor :details
  attr_accessor :retry
  attr_accessor :output
  attr_accessor :secure
  attr_accessor :connect_error
  attr_accessor :log_id
  attr_accessor :time
  attr_accessor :suppress_bounce

  def initialize
    @details = ""
    yield self if block_given?
  end

end
