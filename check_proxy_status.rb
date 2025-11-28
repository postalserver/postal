#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to check proxy installation status
# Usage: bundle exec ruby check_proxy_status.rb

require_relative "config/environment"

puts "\n" + "=" * 80
puts "PROXY INSTALLATION STATUS CHECK"
puts "=" * 80 + "\n"

proxy_ips = IPAddress.where(use_proxy: true).order(updated_at: :desc)

if proxy_ips.empty?
  puts "❌ No proxy IP addresses found in the database."
  exit 0
end

proxy_ips.each do |ip|
  puts "\n📍 IP Address ##{ip.id}"
  puts "   IPv4: #{ip.ipv4 || 'N/A'}"
  puts "   Hostname: #{ip.hostname}"
  puts "   SSH Host: #{ip.proxy_ssh_host}"
  puts "   Status: #{ip.proxy_status}"
  puts "   Last Updated: #{ip.updated_at}"
  puts "   Last Tested: #{ip.proxy_last_tested_at || 'Never'}"

  if ip.proxy_status == "installing"
    elapsed = Time.now - ip.updated_at
    puts "   ⏱️  Installation running for: #{elapsed.round} seconds"

    if elapsed > 300 # 5 minutes
      puts "   ⚠️  WARNING: Installation is taking too long! Possible timeout or error."
    elsif elapsed > 180 # 3 minutes
      puts "   ⚠️  Installation is taking longer than expected..."
    end
  end

  if ip.proxy_last_test_result.present?
    puts "\n   📝 Last Test/Install Log:"
    puts "   " + ("-" * 76)
    ip.proxy_last_test_result.lines.each do |line|
      puts "   #{line}"
    end
    puts "   " + ("-" * 76)
  end

  puts ""
end

puts "\n" + "=" * 80
puts "SUMMARY"
puts "=" * 80
puts "Total proxy IPs: #{proxy_ips.count}"
puts "Installing: #{proxy_ips.where(proxy_status: 'installing').count}"
puts "Active: #{proxy_ips.where(proxy_status: 'active').count}"
puts "Failed: #{proxy_ips.where(proxy_status: 'failed').count}"
puts "Installed (not tested): #{proxy_ips.where(proxy_status: 'installed').count}"
puts "=" * 80 + "\n"

# Check for stuck installations
stuck = proxy_ips.where(proxy_status: 'installing').where("updated_at < ?", 10.minutes.ago)
if stuck.any?
  puts "\n⚠️  WARNING: Found #{stuck.count} installation(s) stuck for >10 minutes!"
  puts "   Consider checking the Rails logs or manually investigating these IPs."
  stuck.each do |ip|
    puts "   - IP ##{ip.id} (#{ip.proxy_ssh_host}) - stuck for #{((Time.now - ip.updated_at) / 60).round} minutes"
  end
end
