# frozen_string_literal: true

require File.expand_path("../lib/postal/config", __dir__)
require "openssl"

key_path = Postal::Config.smtp_server.tls_private_key_path
cert_path = Postal::Config.smtp_server.tls_certificate_path

unless File.exist?(key_path)
  key = OpenSSL::PKey::RSA.new(2048).to_s
  File.write(key_path, key)
  puts "Created new private key for encrypting SMTP connections at #{key_path}"
end

unless File.exist?(cert_path)
  cert = OpenSSL::X509::Certificate.new
  cert.subject = cert.issuer = OpenSSL::X509::Name.parse("/C=GB/O=Test/OU=Test/CN=Test")
  cert.not_before = Time.now
  cert.not_after = Time.now + (365 * 24 * 60 * 60)
  cert.public_key = SMTPServer::Server.tls_private_key.public_key
  cert.serial = 0x0
  cert.version = 2
  cert.sign SMTPServer::Server.tls_private_key, OpenSSL::Digest.new("SHA256")
  File.write(cert_path, cert.to_pem)
  puts "Created new self signed certificate for encrypting SMTP connections at #{cert_path}"
end
