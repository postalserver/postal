#!/usr/bin/env ruby
# frozen_string_literal: true

trap("INT") do
  puts
  exit
end

require_relative "../config/environment"

UserCreator.start do |u|
  u.admin = true
  u.email_verified_at = Time.now
end
