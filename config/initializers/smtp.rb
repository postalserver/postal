# frozen_string_literal: true

require "postal/config"

config = Postal::Config.smtp

ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
  address: config.host,
  user_name: config.username,
  password: config.password,
  port: config.port,
  authentication: config.authentication_type&.to_sym,
  enable_starttls: config.enable_starttls?,
  enable_starttls_auto: config.enable_starttls_auto?,
  openssl_verify_mode: config.openssl_verify_mode
}
