# frozen_string_literal: true

require File.expand_path("../lib/postal/config", __dir__)
require "openssl"

unless File.exist?(Postal.smtp_private_key_path)
  key = OpenSSL::PKey::RSA.new(2048).to_s
  File.write(Postal.smtp_private_key_path, key)
  puts "Created new private key for encrypting SMTP connections"
end

unless File.exist?(Postal.smtp_certificate_path)
  cert = OpenSSL::X509::Certificate.new
  cert.subject = cert.issuer = OpenSSL::X509::Name.parse("/C=GB/O=Test/OU=Test/CN=Test")
  cert.not_before = Time.now
  cert.not_after = Time.now + (365 * 24 * 60 * 60)
  cert.public_key = Postal.smtp_private_key.public_key
  cert.serial = 0x0
  cert.version = 2
  cert.sign Postal.smtp_private_key, OpenSSL::Digest.new("SHA256")
  File.write(Postal.smtp_certificate_path, cert.to_pem)
  puts "Created new self signed certificate for encrypting SMTP connections"
end
