class Admin::StatsController < ApplicationController

  before_action :admin_required

  def stats
    @stats = Statistic.global
    @queue_size = QueuedMessage.unlocked.retriable.count
  end

end
