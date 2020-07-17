#!/usr/bin/env ruby

# This script will build a tgz file containing a copy of Postal with the assets
# ready to go. It will then upload the file to a web server where it can be
# accessed for users who wish to install or upgrade their postal installations.
#
# This script will only be used by the Postal build manager so it's likely of
# little use to most people.

require 'rubygems'
require 'pathname'
require 'fileutils'

ROOT = Pathname.new(File.expand_path('../../', __FILE__))
BUILD_ROOT = Pathname.new("/tmp/postal-build")
WC_PATH = BUILD_ROOT.join('wc')
PACKAGE_PATH = BUILD_ROOT.join('package.tgz')
CHANNEL = ARGV[0]

unless ['beta', 'stable'].include?(CHANNEL)
  puts "channel must be beta or stable"
  exit 1
end

def system!(c)
  if system(c)
    true
  else
    puts "Couldn't execute #{c.inspect}"
    exit 1
  end
end

# Prepare our build root
FileUtils.mkdir_p(BUILD_ROOT)

# Get a brand new clean copy of the repository
puts "\e[44;37mCloning clean repository\e[0m"
system!("rm -rf #{WC_PATH}")
system!("git clone #{ROOT} #{WC_PATH}")

# Install bundler dependencies so we can compile assets
puts "\e[44;37mInstalling dependencies\e[0m"
system!("cd #{WC_PATH} && bundle install --gemfile #{WC_PATH}/Gemfile --path #{BUILD_ROOT}/vendor/bundle")

# Install some configuration files
puts "\e[44;37mInstalling configuration\e[0m"
system!("cd #{WC_PATH} && ./bin/postal initialize-config")

# Get the last commit reference for the version file
last_commit = `git -C #{WC_PATH} log --pretty=oneline -n 1`.split(/\s+/, 2).first[0,10]
puts "\e[34mGot latest commit was #{last_commit}\e[0m"

# Read the version file for the version number so we it put it in the build
# package filename and update the version file to include the REVISION and
# CHANNEL for this build.
version_file = File.read("#{WC_PATH}/lib/postal/version.rb")
if version_file =~ /VERSION = '(.*)'/
  version = $1.to_s
  puts "\e[34mGot version as #{version}\e[0m"
else
  puts "Could not determine version from version file"
  exit 1
end
version_file.gsub!("REVISION = nil", "REVISION = '#{last_commit}'")
version_file.gsub!("CHANNEL = 'dev'", "CHANNEL = '#{CHANNEL}'")
File.open("#{WC_PATH}/lib/postal/version.rb", 'w') { |f| f.write(version_file) }

# Compile all the assets
unless ENV['NO_ASSETS']
  puts "\e[44;37mCompiling assets\e[0m"
  system!("cd #{WC_PATH} && RAILS_GROUPS=assets bundle exec rake assets:precompile")
  system!("touch #{WC_PATH}/public/assets/.prebuilt")
end

# Remove files that shouldn't be distributed
puts "\e[44;37mRemoving unused files\e[0m"
system!("rm -Rf #{WC_PATH}/.git")
system!("rm -f #{WC_PATH}/config/postal.yml")
system!("rm -f #{WC_PATH}/config/*.cert")
system!("rm -f #{WC_PATH}/config/*.key")
system!("rm -f #{WC_PATH}/config/*.pem")
system!("rm -Rf #{WC_PATH}/.bundle")
system!("rm -Rf #{WC_PATH}/.gitignore")
system!("rm -Rf #{WC_PATH}/tmp")

# Build a new tgz file
puts "\e[44;37mCreating build package\e[0m"
system("tar cpzf #{PACKAGE_PATH} -C #{WC_PATH} .")
puts "\e[32mCreated build at #{PACKAGE_PATH}\e[0m"

# What's our filename? This is our filename.
filename = "postal-#{version}-#{last_commit}.tgz"

# Upload the package to the distribution server and symlink it to latest
# for the appropriate channel.
require 'net/ssh'
require 'net/scp'
Net::SSH.start("postal.atech.media") do |ssh|
  ssh.exec!("rm -Rf /home/atechmedia/postal.atech.media/packages/#{CHANNEL}/#{filename}")
  puts "Uploading..."
  ssh.scp.upload!(PACKAGE_PATH.to_s, "/home/atechmedia/postal.atech.media/packages/#{CHANNEL}/#{filename}")
  puts "Making latest..."
  ssh.exec!("rm -Rf /home/atechmedia/postal.atech.media/packages/#{CHANNEL}/latest.tgz")
  ssh.exec!("ln -s /home/atechmedia/postal.atech.media/packages/#{CHANNEL}/#{filename} /home/atechmedia/postal.atech.media/packages/#{CHANNEL}/latest.tgz")
end

puts "\e[32mDone. Package is live at https://postal.atech.media/packages/#{CHANNEL}/latest.tgz\e[0m"

# Yay. We're done.
