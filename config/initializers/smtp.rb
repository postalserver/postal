# frozen_string_literal: true

require "postal/config"

if Postal.config&.smtp
  # TODO: by default, we should just send mail through the local Postal
  # installation rather than having to actually configure an SMTP server.
  ActionMailer::Base.delivery_method = :smtp
  ActionMailer::Base.smtp_settings = { address: Postal.config.smtp.host, user_name: Postal.config.smtp.username, password: Postal.config.smtp.password, port: Postal.config.smtp.port || 25 }
end
