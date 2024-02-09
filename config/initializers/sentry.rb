# frozen_string_literal: true
require "postal/config"

if Postal.config.general&.exception_url
  Sentry.init do |config|
    config.dsn = Postal.config.general.exception_url
  end
end
