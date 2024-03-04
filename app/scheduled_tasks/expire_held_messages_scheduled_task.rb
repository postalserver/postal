# frozen_string_literal: true

class ExpireHeldMessagesScheduledTask < ApplicationScheduledTask

  def call
    Server.all.each do |server|
      messages = server.message_db.messages(where: {
        status: "Held",
        hold_expiry: { less_than: Time.now.to_f }
      })

      messages.each(&:cancel_hold)
    end
  end

end
