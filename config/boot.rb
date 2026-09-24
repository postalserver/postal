# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

require_relative "../lib/postal/config"

ENV["RAILS_ENV"] = Postal::Config.rails.environment || "development"

# Rails reads the session secret from SECRET_KEY_BASE before the application
# initializes, so a secret kept in Postal's own config file has to be exported
# here. Without either, production raises a clear error at boot instead of
# running with an ephemeral secret.
ENV["SECRET_KEY_BASE"] ||= Postal::Config.rails.secret_key if Postal::Config.rails.secret_key
