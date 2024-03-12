# frozen_string_literal: true

class TidyQueuedMessagesTask < ApplicationScheduledTask

  def call
    QueuedMessage.with_stale_lock.in_batches do |messages|
      messages.each do |message|
        logger.info "removing queued message #{message.id} (locked at #{message.locked_at} by #{message.locked_by})"
        message.destroy
      end
    end
  end

  def self.next_run_after
    quarter_to_each_hour
  end

end
