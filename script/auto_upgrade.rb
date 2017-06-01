#!/usr/bin/env ruby

# This script will attempt to upgrade a Postal installation automatically.
#
# It can be run as any user that has access to /opt/postal and that can run
# commands as postal.

channel = 'stable'
safe_mode = false

begin
  require 'optparse'
  OptionParser.new do |opts|
    opts.banner = "Usage: postal auto-upgrade [options]"

    opts.on("-c", "--channel CHANNEL", "The channel to pull the latest version from") do |v|
      channel = v
    end

    opts.on("--safe", "Stop postal before running the upgrade") do |v|
      safe_mode = true
    end
  end.parse!
rescue OptionParser::InvalidOption => e
  puts e.message
  exit 1
end

unless ['beta', 'stable'].include?(channel)
  puts "Channel must be either 'stable' or 'beta'"
  exit 1
end

puts "Upgrading from the \e[32m#{channel}\e[0m channel"

def run(command, options = {})
  if system(command)
    # Good.
  else
    puts "Failed to run: #{command}"
    exit 128 unless options[:exit_on_failure] == false
  end
end

if safe_mode
  puts "Stopping current Postal instance"
  run "postal stop", :exit_on_failure => false
end

if File.exist?("/opt/postal/app/.git")
  puts "Getting latest version of repository"
  run "cd /opt/postal/app && git pull"
else
  puts "Backing up previous application files"
  run "rm -Rf /opt/postal/app.backup"
  run "cp -R /opt/postal/app /opt/postal/app.backup"
  puts "Downloading latest version of application"
  run "wget https://postal.atech.media/packages/#{channel}/latest.tgz -O - | tar zxpv -C /opt/postal/app"
end

puts "Installing dependencies"
run "postal bundle /opt/postal/vendor/bundle"

puts "Upgrading database & assets"
run "postal upgrade"

if safe_mode
  puts "Starting Postal"
  run "postal start"
else
  puts "Restarting Postal"
  run "postal restart"
end

puts "\e[32mUpgrade complete\e[0m"
