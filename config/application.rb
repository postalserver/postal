# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "sprockets/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
gem_groups = Rails.groups
gem_groups << :oidc if Postal::Config.oidc.enabled?
Bundler.require(*gem_groups)

module Postal
  class Application < Rails::Application

    config.load_defaults 8.1

    # Disable most generators
    config.generators do |g|
      g.orm             :active_record
      g.test_framework  false
      g.stylesheets     false
      g.javascripts     false
      g.helper          false
    end

    # Include from lib
    config.eager_load_paths << Rails.root.join("lib")

    # Disable field_with_errors
    config.action_view.field_error_proc = proc { |t, _| t }

    # Load the tracking server middleware
    require "tracking_middleware"
    config.middleware.insert_before ActionDispatch::HostAuthorization, TrackingMiddleware

    config.hosts << Postal::Config.postal.web_hostname

    # An MTA-STS policy is served from the mta-sts.<domain> host of each domain
    # which is hosted here, so those hosts have to be accepted.
    config.hosts << /\Amta-sts\..+\z/i

    unless Postal::Config.logging.rails_log_enabled?
      config.logger = Logger.new("/dev/null")
    end

  end
end
