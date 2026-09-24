# frozen_string_literal: true

class DKIMKeyChangeScheduledTask < ApplicationScheduledTask

  # The period a key change can wait to be published before we remind the owner
  # about it. Reminders are sent once for each key change.
  REMIND_AFTER = 7.days

  def call
    Domain.dkim_key_change_notifiable(REMIND_AFTER).each do |domain|
      logger.info "reminding about the pending DKIM key for #{domain.name}"
      domain.notify_pending_dkim_key!
    end
  end

  def self.next_run_after
    three_am
  end

end
