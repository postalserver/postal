# frozen_string_literal: true

class SendNotificationsScheduledTask < ApplicationScheduledTask

  def call
    Server.send_send_limit_notifications
  end

  def self.next_run_after
    1.minute.from_now
  end

end
