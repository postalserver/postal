require_relative '../config/application'
require 'postal/lets_encrypt'

if ARGV[0].nil?
  puts "e-mail address missing"
  exit 1
end

begin
  Postal::LetsEncrypt.register_private_key(ARGV[0])
  puts "Done"
rescue => e
  puts "#{e.class}: #{e.message}"
  exit 1
end
