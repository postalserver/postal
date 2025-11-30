# frozen_string_literal: true

namespace :management_api do
  desc "List all Management API keys"
  task list_keys: :environment do
    keys = ManagementAPIKey.order(created_at: :desc)

    if keys.empty?
      puts "No Management API keys found."
    else
      puts ""
      puts "Management API Keys"
      puts "=" * 80

      keys.each do |key|
        status = key.enabled? ? "enabled" : "disabled"
        status += " (expired)" if key.expired?
        scope = key.super_admin? ? "super_admin" : "org:#{key.organization&.permalink}"

        puts ""
        puts "UUID:         #{key.uuid}"
        puts "Name:         #{key.name}"
        puts "Scope:        #{scope}"
        puts "Status:       #{status}"
        puts "Requests:     #{key.request_count}"
        puts "Last Used:    #{key.last_used_at&.strftime('%Y-%m-%d %H:%M:%S') || 'Never'}"
        puts "Created:      #{key.created_at.strftime('%Y-%m-%d %H:%M:%S')}"
        puts "-" * 40
      end

      puts ""
      puts "Total: #{keys.count} key(s)"
    end
  end

  desc "Create a super admin Management API key"
  task :create_key, [:name] => :environment do |_t, args|
    name = args[:name] || "Management API Key"

    key = ManagementAPIKey.new(
      name: name,
      super_admin: true,
      description: "Created via rake task"
    )

    if key.save
      puts ""
      puts "Management API key created successfully!"
      puts ""
      puts "Name:      #{key.name}"
      puts "UUID:      #{key.uuid}"
      puts "API Key:   #{key.key}"
      puts "Scope:     Super Admin (full access)"
      puts ""
      puts "IMPORTANT: Save this API key securely. It will not be shown again."
      puts ""
    else
      puts "Failed to create API key:"
      key.errors.full_messages.each do |msg|
        puts "  - #{msg}"
      end
      exit 1
    end
  end

  desc "Create an organization-scoped Management API key"
  task :create_org_key, [:name, :org_permalink] => :environment do |_t, args|
    unless args[:name] && args[:org_permalink]
      puts "Usage: rake management_api:create_org_key[name,org_permalink]"
      exit 1
    end

    org = Organization.find_by(permalink: args[:org_permalink])
    unless org
      puts "Organization '#{args[:org_permalink]}' not found."
      exit 1
    end

    key = ManagementAPIKey.new(
      name: args[:name],
      organization: org,
      super_admin: false,
      description: "Created via rake task for #{org.name}"
    )

    if key.save
      puts ""
      puts "Management API key created successfully!"
      puts ""
      puts "Name:         #{key.name}"
      puts "UUID:         #{key.uuid}"
      puts "API Key:      #{key.key}"
      puts "Organization: #{org.name} (#{org.permalink})"
      puts ""
      puts "IMPORTANT: Save this API key securely. It will not be shown again."
      puts ""
    else
      puts "Failed to create API key:"
      key.errors.full_messages.each do |msg|
        puts "  - #{msg}"
      end
      exit 1
    end
  end

  desc "Enable a Management API key"
  task :enable_key, [:uuid] => :environment do |_t, args|
    unless args[:uuid]
      puts "Usage: rake management_api:enable_key[uuid]"
      exit 1
    end

    key = ManagementAPIKey.find_by(uuid: args[:uuid])
    unless key
      puts "API key with UUID '#{args[:uuid]}' not found."
      exit 1
    end

    key.update!(enabled: true)
    puts "API key '#{key.name}' has been enabled."
  end

  desc "Disable a Management API key"
  task :disable_key, [:uuid] => :environment do |_t, args|
    unless args[:uuid]
      puts "Usage: rake management_api:disable_key[uuid]"
      exit 1
    end

    key = ManagementAPIKey.find_by(uuid: args[:uuid])
    unless key
      puts "API key with UUID '#{args[:uuid]}' not found."
      exit 1
    end

    key.update!(enabled: false)
    puts "API key '#{key.name}' has been disabled."
  end

  desc "Delete a Management API key"
  task :delete_key, [:uuid] => :environment do |_t, args|
    unless args[:uuid]
      puts "Usage: rake management_api:delete_key[uuid]"
      exit 1
    end

    key = ManagementAPIKey.find_by(uuid: args[:uuid])
    unless key
      puts "API key with UUID '#{args[:uuid]}' not found."
      exit 1
    end

    key.destroy!
    puts "API key '#{key.name}' has been deleted."
  end

  desc "Show details of a specific Management API key"
  task :show_key, [:uuid] => :environment do |_t, args|
    unless args[:uuid]
      puts "Usage: rake management_api:show_key[uuid]"
      exit 1
    end

    key = ManagementAPIKey.find_by(uuid: args[:uuid])
    unless key
      puts "API key with UUID '#{args[:uuid]}' not found."
      exit 1
    end

    puts ""
    puts "Management API Key Details"
    puts "=" * 40
    puts "UUID:          #{key.uuid}"
    puts "Name:          #{key.name}"
    puts "Description:   #{key.description || 'N/A'}"
    puts "Super Admin:   #{key.super_admin? ? 'Yes' : 'No'}"
    puts "Organization:  #{key.organization&.name || 'N/A'}"
    puts "Enabled:       #{key.enabled? ? 'Yes' : 'No'}"
    puts "Expired:       #{key.expired? ? 'Yes' : 'No'}"
    puts "Expires At:    #{key.expires_at&.strftime('%Y-%m-%d %H:%M:%S') || 'Never'}"
    puts "Request Count: #{key.request_count}"
    puts "Last Used At:  #{key.last_used_at&.strftime('%Y-%m-%d %H:%M:%S') || 'Never'}"
    puts "Last Used IP:  #{key.last_used_ip || 'N/A'}"
    puts "Created At:    #{key.created_at.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "Updated At:    #{key.updated_at.strftime('%Y-%m-%d %H:%M:%S')}"
    puts ""
  end

  desc "Clean up expired Management API keys"
  task cleanup_expired: :environment do
    expired_keys = ManagementAPIKey.where("expires_at IS NOT NULL AND expires_at < ?", Time.current)
    count = expired_keys.count

    if count.zero?
      puts "No expired API keys found."
    else
      expired_keys.destroy_all
      puts "Deleted #{count} expired API key(s)."
    end
  end
end
