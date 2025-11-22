# frozen_string_literal: true

namespace :management_api do
  desc "Create a new Management API key"
  task :create_key, [:name] => :environment do |_, args|
    name = args[:name] || "Default Management API Key"

    puts "Creating Management API key..."
    puts ""

    api_key = ManagementAPIKey.new(
      name: name,
      super_admin: true,
      description: "Created via rake task on #{Time.current}"
    )

    if api_key.save
      puts "=" * 60
      puts "Management API Key Created Successfully!"
      puts "=" * 60
      puts ""
      puts "Name:        #{api_key.name}"
      puts "UUID:        #{api_key.uuid}"
      puts "Super Admin: #{api_key.super_admin?}"
      puts ""
      puts "API Key:     #{api_key.key}"
      puts ""
      puts "=" * 60
      puts "IMPORTANT: Save this key securely. It cannot be retrieved later!"
      puts "=" * 60
    else
      puts "Failed to create API key:"
      api_key.errors.full_messages.each do |msg|
        puts "  - #{msg}"
      end
      exit 1
    end
  end

  desc "Create an organization-scoped Management API key"
  task :create_org_key, [:name, :org_permalink] => :environment do |_, args|
    unless args[:org_permalink]
      puts "Usage: rake management_api:create_org_key[name,org_permalink]"
      exit 1
    end

    org = Organization.find_by(permalink: args[:org_permalink])
    unless org
      puts "Organization not found: #{args[:org_permalink]}"
      exit 1
    end

    name = args[:name] || "API Key for #{org.name}"

    api_key = ManagementAPIKey.new(
      name: name,
      organization: org,
      super_admin: false,
      description: "Created via rake task on #{Time.current}"
    )

    if api_key.save
      puts "=" * 60
      puts "Management API Key Created Successfully!"
      puts "=" * 60
      puts ""
      puts "Name:         #{api_key.name}"
      puts "UUID:         #{api_key.uuid}"
      puts "Organization: #{org.name} (#{org.permalink})"
      puts "Super Admin:  #{api_key.super_admin?}"
      puts ""
      puts "API Key:      #{api_key.key}"
      puts ""
      puts "=" * 60
      puts "IMPORTANT: Save this key securely. It cannot be retrieved later!"
      puts "=" * 60
    else
      puts "Failed to create API key:"
      api_key.errors.full_messages.each do |msg|
        puts "  - #{msg}"
      end
      exit 1
    end
  end

  desc "List all Management API keys"
  task list_keys: :environment do
    keys = ManagementAPIKey.order(created_at: :desc)

    if keys.empty?
      puts "No Management API keys found."
      exit 0
    end

    puts "Management API Keys:"
    puts "=" * 80
    puts ""

    keys.each do |key|
      status = key.active? ? "Active" : (key.expired? ? "Expired" : "Disabled")
      org_info = key.organization ? "#{key.organization.name} (#{key.organization.permalink})" : "All (Super Admin)"

      puts "UUID:         #{key.uuid}"
      puts "Name:         #{key.name}"
      puts "Status:       #{status}"
      puts "Scope:        #{org_info}"
      puts "Super Admin:  #{key.super_admin?}"
      puts "Requests:     #{key.request_count}"
      puts "Last Used:    #{key.last_used_at&.strftime('%Y-%m-%d %H:%M:%S') || 'Never'}"
      puts "Created:      #{key.created_at.strftime('%Y-%m-%d %H:%M:%S')}"
      puts "-" * 80
      puts ""
    end
  end

  desc "Disable a Management API key"
  task :disable_key, [:uuid] => :environment do |_, args|
    unless args[:uuid]
      puts "Usage: rake management_api:disable_key[uuid]"
      exit 1
    end

    key = ManagementAPIKey.find_by(uuid: args[:uuid])
    unless key
      puts "API key not found: #{args[:uuid]}"
      exit 1
    end

    key.update!(enabled: false)
    puts "API key disabled: #{key.name} (#{key.uuid})"
  end

  desc "Enable a Management API key"
  task :enable_key, [:uuid] => :environment do |_, args|
    unless args[:uuid]
      puts "Usage: rake management_api:enable_key[uuid]"
      exit 1
    end

    key = ManagementAPIKey.find_by(uuid: args[:uuid])
    unless key
      puts "API key not found: #{args[:uuid]}"
      exit 1
    end

    key.update!(enabled: true)
    puts "API key enabled: #{key.name} (#{key.uuid})"
  end

  desc "Delete a Management API key"
  task :delete_key, [:uuid] => :environment do |_, args|
    unless args[:uuid]
      puts "Usage: rake management_api:delete_key[uuid]"
      exit 1
    end

    key = ManagementAPIKey.find_by(uuid: args[:uuid])
    unless key
      puts "API key not found: #{args[:uuid]}"
      exit 1
    end

    key.destroy
    puts "API key deleted: #{key.name} (#{key.uuid})"
  end
end
