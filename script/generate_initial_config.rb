#!/usr/bin/env ruby
# frozen_string_literal: true
require File.expand_path("../lib/postal/config", __dir__)
require "openssl"
require "securerandom"
require "fileutils"

unless File.directory?(Postal.config_root)
  FileUtils.mkdir_p(Postal.config_root)
end

unless File.exist?(Postal.config_file_path)
  content = File.read(Postal.app_root.join("config", "postal.example.yml"))
  content.gsub!("{{secretkey}}", SecureRandom.hex(128))
  File.write(Postal.config_file_path, content)
  puts "Created example config file at #{Postal.config_file_path}"
end

unless File.exist?(Postal.signing_key_path)
  key = OpenSSL::PKey::RSA.new(1024).to_s
  File.write(Postal.signing_key_path, key)
  puts "Created new signing key for DKIM & HTTP requests"
end
