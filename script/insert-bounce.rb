#!/usr/bin/env ruby
# frozen_string_literal: true

# This script will insert a message into your database that looks like a bounce
# for a message that you specify.

# usage: insert-bounce.rb [serverid] [messageid] [bounce_type]
# bounce_type is optional and can be 'soft' or 'hard'

if ARGV[0].nil? || ARGV[1].nil?
  puts "usage: #{__FILE__} [server-id] [message-id] [bounce_type]"
  puts "bounce_type is optional and can be 'soft' or 'hard'"
  exit 1
end

# Validate bounce_type if provided
bounce_type = nil
if ARGV[2]
  bounce_type = ARGV[2].downcase
  unless %w[soft hard].include?(bounce_type)
    puts "Error: bounce_type must be either 'soft' or 'hard'"
    puts "usage: #{__FILE__} [server-id] [message-id] [bounce_type]"
    exit 1
  end
end

require_relative "../config/environment"

server = Server.find(ARGV[0])
puts "Got server #{server.name}"

template = File.read(Rails.root.join("resource/postfix-bounce.msg"))

if ARGV[1].to_s =~ /\A(\d+)\z/
  original_message = server.message_db.message(ARGV[1].to_i)
  puts "Got message #{original_message.id} with token #{original_message.token}"
  template.gsub!("{{MSGID}}", original_message.token)
else
  template.gsub!("{{MSGID}}", ARGV[1].to_s)
end

message = server.message_db.new_message
message.scope = "incoming"
message.rcpt_to = "#{server.token}@#{Postal::Config.dns.return_path_domain}"
message.mail_from = "MAILER-DAEMON@smtp.infra.atech.io"
message.raw_message = template
message.bounce = true

# Set bounce_type if provided
if bounce_type
  message.bounce_type = bounce_type
  puts "Setting bounce_type to: #{bounce_type}"
end

message.save
puts "Added message with id #{message.id}"

# If we found the original message and bounce_type is set, link the bounce and trigger webhook
if defined?(original_message) && bounce_type
  message.update(bounce_for_id: original_message.id, domain_id: original_message.domain_id)
  original_message.bounce!(message)
  puts "Linked bounce to original message #{original_message.id} and triggered webhook"
end
