#!/usr/bin/env ruby
require File.expand_path('../../lib/postal/config', __FILE__)
require 'openssl'
require 'securerandom'
require 'fileutils'

unless File.directory?(Postal.config_root)
  FileUtils.mkdir_p(Postal.config_root)
end

unless File.exist?(Postal.config_file_path)
  content = File.read(Postal.app_root.join('config', 'postal.example.yml'))
  content.gsub!('{{secretkey}}', SecureRandom.hex(128))
  File.open(Postal.config_file_path, 'w') { |f| f.write(content) }
  puts "Created example config file at #{Postal.config_file_path}"
end

unless File.exists?(Postal.smtp_private_key_path)
  key = OpenSSL::PKey::RSA.new(2048).to_s
  File.open(Postal.smtp_private_key_path, 'w') { |f| f.write(key) }
  puts "Created new private key for encrypting SMTP connections"
end

unless File.exist?(Postal.smtp_certificate_path)
  cert = OpenSSL::X509::Certificate.new
  cert.subject = cert.issuer = OpenSSL::X509::Name.parse("/C=GB/O=Test/OU=Test/CN=Test")
  cert.not_before = Time.now
  cert.not_after = Time.now + 365 * 24 * 60 * 60
  cert.public_key = Postal.smtp_private_key.public_key
  cert.serial = 0x0
  cert.version = 2
  cert.sign Postal.smtp_private_key, OpenSSL::Digest::SHA256.new
  File.open(Postal.smtp_certificate_path, 'w') { |f| f.write(cert.to_pem) }
  puts "Created new self signed certificate for encrypting SMTP connections"
end

unless File.exists?(Postal.lets_encrypt_private_key_path)
  key = OpenSSL::PKey::RSA.new(2048).to_s
  File.open(Postal.lets_encrypt_private_key_path, 'w') { |f| f.write(key) }
  puts "Created new private key for Let's Encrypt"
end

unless File.exists?(Postal.signing_key_path)
  key = OpenSSL::PKey::RSA.new(1024).to_s
  File.open(Postal.signing_key_path, 'w') { |f| f.write(key) }
  puts "Created new signing key for DKIM & HTTP requests"
end
