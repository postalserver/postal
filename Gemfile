# frozen_string_literal: true

source "https://rubygems.org"
gem "abbrev"
gem "authie"
gem "autoprefixer-rails"
gem "bcrypt"
gem "chronic"
gem "domain_name"
gem "dotenv"
gem "execjs"
gem "gelf"
gem "haml"
gem "hashie"
gem "highline", require: false
# json 3.0 removed the `quirks_mode` option, which Active Support 7.2 still
# passes in both its JSON encoder and decoder. Nothing else constrains json, so
# without this pin Bundler resolves to 3.x and every `to_json` call raises
# ArgumentError. Active Support dropped those calls in Rails 8.1, so this pin
# can go when we move to 8.1.
gem "json", "< 3"
gem "jwt"
gem "kaminari"
gem "klogger-logger"
gem "konfig-config", "~> 3.0"
gem "logger"
gem "mail"
gem "mutex_m"
gem "mysql2"
gem "nifty-utils"
gem "nilify_blanks"
gem "nio4r"
gem "ostruct"
gem "prometheus-client"
gem "puma"
gem "rackup"
gem "rails", "= 7.2.3.2"
gem "resolv"
gem "secure_headers"
gem "sentry-rails"
gem "turbolinks", "~> 5"
gem "webrick"

group :oidc do
  # These are gems which are needed for OpenID connect. They are only required by the application
  # when OIDC is enabled in the Postal configuration.
  gem "omniauth_openid_connect"
  gem "omniauth-rails_csrf_protection"
end

group :development, :test, :assets do
  gem "coffee-rails", "~> 5.0"
  gem "jquery-rails"
  gem "sass-rails"
  gem "uglifier", ">= 1.3.0"
end

group :development do
  gem "annotate"
  gem "rubocop"
  gem "rubocop-rails"
end

group :test do
  gem "database_cleaner-active_record"
  gem "factory_bot_rails"
  gem "rspec"
  gem "rspec-rails"
  gem "shoulda-matchers"
  gem "timecop"
  gem "webmock"
end
