# frozen_string_literal: true

class PruneSuppressionListsScheduledTask < ApplicationScheduledTask

  def call
    Server.all.each do |s|
      logger.info "Pruning suppression lists for server #{s.id}"
      s.message_db.suppression_list.prune
    end
  end

  def self.next_run_after
    three_am
  end

end
