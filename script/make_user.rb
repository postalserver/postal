#!/usr/bin/env ruby
trap("INT") do
  puts
  exit
end

require_relative "../config/environment"
require "postal/user_creator"

Postal::UserCreator.start do |u|
  u.admin = true
  u.email_verified_at = Time.now
end
