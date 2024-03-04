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

  desc "Generate configuration documentation"
  task generate_config_docs: :environment do
    require "konfig/exporters/env_vars_as_markdown"

    FileUtils.mkdir_p("doc/config")
    output = Konfig::Exporters::EnvVarsAsMarkdown.new(Postal::ConfigSchema).export
    File.write("doc/config/environment-variables.md", output)

    output = Postal::YamlConfigExporter.new(Postal::ConfigSchema).export
    File.write("doc/config/yaml.yml", output)
  end
end

Rake::Task["db:migrate"].enhance do
  Rake::Task["postal:migrate_message_databases"].invoke
end
