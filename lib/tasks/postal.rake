# frozen_string_literal: true

namespace :postal do
  desc "Run all migrations on message databases"
  task migrate_message_databases: :environment do
    Server.all.each do |server|
      puts "\e[35m-------------------------------------------------------------------\e[0m"
      puts "\e[35m#{server.id}: #{server.name} (#{server.permalink})\e[0m"
      puts "\e[35m-------------------------------------------------------------------\e[0m"
      server.message_db.provisioner.migrate
    end
  end
end

Rake::Task["db:migrate"].enhance do
  Rake::Task["postal:migrate_message_databases"].invoke
end
