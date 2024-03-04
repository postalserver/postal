# frozen_string_literal: true

# This script will automatically send an HTML email to the
# SMTP server given.

require "mail"
require "net/smtp"

from = ARGV[0]
to = ARGV[1]

if from.nil? || to.nil?
  puts "Usage: ruby send-html-email.rb <from> <to>"
  exit 1
end

mail = Mail.new
mail.to = to
mail.from = from
mail.subject = "A test email from #{Time.now}"
mail["X-Postal-Tag"] = "send-html-email-script"
mail.text_part = Mail::Part.new do
  body <<~BODY
    Hello there.

    This is an example. It doesn't do all that much.

    Some other characters: őúéáűí

    There is a link here through... https://postalserver.io/test-plain-text-link?foo=bar&baz=qux
  BODY
end
mail.html_part = Mail::Part.new do
  content_type "text/html; charset=UTF-8"
  body <<~BODY
    <p>Hello there</p>
    <p>This is an example email. It doesn't do all that much.</p>
    <p>Some other characters: őúéáűí</p>
    <p>There is a <a href='https://postalserver.io/test-plain-text-link?foo=bar&amp;baz=qux'>link here</a> though...</p>
  BODY
end

c = OpenSSL::SSL::SSLContext.new
c.verify_mode = OpenSSL::SSL::VERIFY_NONE

smtp = Net::SMTP.new("127.0.0.1", 2525)
smtp.enable_starttls(c)
smtp.start("localhost")
smtp.send_message mail.to_s, mail.from.first, mail.to.first
smtp.finish

puts "Sent"
