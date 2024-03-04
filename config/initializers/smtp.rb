# frozen_string_literal: true

require "postal/config"

ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
  address: Postal::Config.smtp.host,
  user_name: Postal::Config.smtp.username,
  password: Postal::Config.smtp.password,
  port: Postal::Config.smtp.port
}
