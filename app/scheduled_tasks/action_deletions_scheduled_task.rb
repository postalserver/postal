# frozen_string_literal: true

class ActionDeletionsScheduledTask < ApplicationScheduledTask

  def call
    Organization.deleted.each do |org|
      logger.info "permanently removing organization #{org.id} (#{org.permalink})"
      org.destroy
    end

    Server.deleted.each do |server|
      logger.info "permanently removing server #{server.id} (#{server.full_permalink})"
      server.destroy
    end
  end

end
