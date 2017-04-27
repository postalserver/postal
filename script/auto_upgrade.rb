#!/usr/bin/env ruby

# This script will attempt to upgrade a Postal installation automatically.
# It is always recommended to upgrade Postal manaually and this script should only
# be used for development or for pro-users.
#
# It can be run as any user that has access to /opt/postal and that can run
# commands as postal.

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

puts "Getting latest version of repository"
run "cd /opt/postal/app && git pull"

puts "Installing dependencies"
run "postal bundle /opt/postal/app/vendor/bundle"

puts "Upgrading database & assets"
run "postal upgrade"

puts "Starting Postal"
run "postal start"

puts "\e[32mUpgrade complete\e[0m"
