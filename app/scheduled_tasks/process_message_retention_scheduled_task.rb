# frozen_string_literal: true

class ProcessMessageRetentionScheduledTask < ApplicationScheduledTask

  def call
    Server.all.each do |server|
      if server.raw_message_retention_days
        # If the server has a maximum number of retained raw messages, remove any that are older than this
        logger.info "Tidying raw messages (by days) for #{server.permalink} (ID: #{server.id}). Keeping #{server.raw_message_retention_days} days."
        server.message_db.provisioner.remove_raw_tables_older_than(server.raw_message_retention_days)
      end

      if server.raw_message_retention_size
        logger.info "Tidying raw messages (by size) for #{server.permalink} (ID: #{server.id}). Keeping #{server.raw_message_retention_size} MB of data."
        server.message_db.provisioner.remove_raw_tables_until_less_than_size(server.raw_message_retention_size * 1024 * 1024)
      end

      if server.message_retention_days
        logger.info "Tidying messages for #{server.permalink} (ID: #{server.id}). Keeping #{server.message_retention_days} days."
        server.message_db.provisioner.remove_messages(server.message_retention_days)
      end
    end
  end

  def self.next_run_after
    three_am
  end

end
