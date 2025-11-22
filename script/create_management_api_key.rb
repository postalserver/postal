#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to create a Management API key
# Usage: postal run script/create_management_api_key.rb [name] [--super-admin] [--org=permalink]

require_relative "../config/environment"

name = ARGV.find { |arg| !arg.start_with?("--") } || "Management API Key"
super_admin = ARGV.include?("--super-admin")
org_flag = ARGV.find { |arg| arg.start_with?("--org=") }
org_permalink = org_flag&.split("=", 2)&.last

if org_permalink && super_admin
  puts "Error: Cannot specify both --super-admin and --org"
  exit 1
end

organization = nil
if org_permalink
  organization = Organization.find_by(permalink: org_permalink)
  unless organization
    puts "Error: Organization not found: #{org_permalink}"
    exit 1
  end
end

api_key = ManagementApiKey.new(
  name: name,
  super_admin: super_admin || org_permalink.nil?,
  organization: organization,
  description: "Created via script on #{Time.current}"
)

if api_key.save
  puts ""
  puts "=" * 70
  puts "  MANAGEMENT API KEY CREATED SUCCESSFULLY"
  puts "=" * 70
  puts ""
  puts "  Name:         #{api_key.name}"
  puts "  UUID:         #{api_key.uuid}"
  puts "  Super Admin:  #{api_key.super_admin?}"
  if organization
    puts "  Organization: #{organization.name} (#{organization.permalink})"
  else
    puts "  Scope:        All organizations"
  end
  puts ""
  puts "  API Key:"
  puts "  #{api_key.key}"
  puts ""
  puts "=" * 70
  puts "  IMPORTANT: Save this key securely!"
  puts "  It cannot be retrieved later."
  puts "=" * 70
  puts ""
  puts "  Usage example:"
  puts "  curl -H 'X-Management-API-Key: #{api_key.key}' \\"
  puts "       https://postal.example.com/api/v2/management/system/status"
  puts ""
else
  puts "Error: Failed to create API key"
  api_key.errors.full_messages.each do |msg|
    puts "  - #{msg}"
  end
  exit 1
end
