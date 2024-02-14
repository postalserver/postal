# frozen_string_literal: true

class PruneWebhookRequestsScheduledTask < ApplicationScheduledTask

  def call
    Server.all.each do |s|
      logger.info "Pruning webhook requests for server #{s.id}"
      s.message_db.webhooks.prune
    end
  end

  def self.next_run_after
    quarter_to_each_hour
  end

end
