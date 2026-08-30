# frozen_string_literal: true

namespace :postal do
  namespace :control_api do
    desc "Create the first platform control API key"
    task :bootstrap_key, [:name] => :environment do |_task, args|
      if ControlAPIKey.active.where(organization_id: nil).where("scopes LIKE ?", "%platform:admin%").exists?
        abort "A platform control API key already exists. Create additional keys through an approved operator workflow."
      end

      key, token = ControlAPIKey.issue!(name: args[:name].presence || "bootstrap", scopes: ["platform:admin"])
      puts "Control API key #{key.uuid} created. Store this token now; it will not be shown again:"
      puts token
    end
  end
end
