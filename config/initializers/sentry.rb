# frozen_string_literal: true

require "postal/config"

if Postal::Config.logging.sentry_dsn
  Sentry.init do |config|
    config.dsn = Postal::Config.logging.sentry_dsn
  end
end
