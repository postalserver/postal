# frozen_string_literal: true

require "authie/session"

class CleanupAuthieSessionsScheduledTask < ApplicationScheduledTask

  def call
    Authie::Session.cleanup
  end

end
