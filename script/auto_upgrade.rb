#!/usr/bin/env ruby

# This script will attempt to upgrade a Postal installation automatically.
# It is always recommended to upgrade Postal manaually and this script should only
# be used for development or for pro-users.
#
# It can be run as any user that has access to /opt/postal and that can run
# commands as postal.

CHANNEL = ARGV[0] || "stable"

unless ['beta', 'stable'].include?(CHANNEL)
  puts "Channel must be either 'stable' or 'beta'"
  exit 1
end

def run(command, options = {})
  if system(command)
    # Good.
  else
    puts "Failed to run: #{command}"
    exit 128 unless options[:exit_on_failure] == false
  end
end

puts "Stopping current Postal instance"
run "postal stop", :exit_on_failure => false

if File.exist?("/opt/postal/app/.git")
  puts "Getting latest version of repository"
  run "cd /opt/postal/app && git pull"
else
  puts "Backing up previous application files"
  run "rm -Rf /opt/postal/app.backup"
  run "cp -R /opt/postal/app /opt/postal/app.backup"
  puts "Downloading latest version of application"
  run "wget https://postal.atech.media/packages/#{CHANNEL}/latest.tgz -O - | tar zxpv -C /opt/postal/app"
end

puts "Installing dependencies"
run "postal bundle /opt/postal/vendor/bundle"

puts "Upgrading database & assets"
run "postal upgrade"

puts "Starting Postal"
run "postal start"

puts "\e[32mUpgrade complete\e[0m"
