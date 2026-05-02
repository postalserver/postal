# frozen_string_literal: true

class TidyWebhookRequestsTask < ApplicationScheduledTask

  def call
    WebhookRequest.with_stale_lock.find_each do |request|
      logger.info "unlocking stale webhook request #{request.id} (locked at #{request.locked_at} by #{request.locked_by})"
      request.unlock
    end
  end

  def self.next_run_after
    quarter_to_each_hour
  end

end
