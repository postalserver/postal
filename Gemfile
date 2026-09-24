# frozen_string_literal: true

source "https://rubygems.org"
gem "abbrev"
gem "authie"
gem "autoprefixer-rails"
gem "base64"
gem "bcrypt"
gem "benchmark"
gem "cgi"
gem "chronic"
gem "domain_name"
gem "dotenv"
gem "execjs"
gem "gelf"
gem "haml"
gem "hashie"
gem "highline", require: false
# json 3.0 removed the `quirks_mode` option, which Active Support 7.2 still passes
# in both its JSON encoder and decoder. Nothing else constrains json, so without
# this pin Bundler resolves to 3.x and every `to_json` call raises ArgumentError.
# Active Support 8.1 still passes it, so the pin stays until it does not.
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
gem "pg"
gem "prometheus-client"
gem "puma"
gem "rackup"
gem "rails", "~> 8.1.3"
gem "resolv"
gem "secure_headers"
gem "securerandom"
gem "sentry-rails"
gem "sprockets-rails"
gem "timeout"
gem "turbo-rails", "~> 2"
gem "webrick"

group :oidc do
  # These are gems which are needed for OpenID connect. They are only required by the application
  # when OIDC is enabled in the Postal configuration.
  gem "omniauth_openid_connect"
  gem "omniauth-rails_csrf_protection"
end

group :development, :test, :assets do
  gem "dartsass-rails"
  gem "terser"
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
  gem "webmock"
end

# Optional analytics: an embedded OLAP engine used to mirror statistics
# extracts. It needs the DuckDB C library in the image, so it is not installed
# by default. Enable it with `bundle config set --local with analytics`.
group :analytics, optional: true do
  gem "duckdb"
end

# Optional in-memory store, spoken over the Redis protocol: the live statistics
# are kept here, and it is also the shared store for rate limit counters, so that
# a limit applies to the whole deployment rather than to each worker. The group is
# named for Redis, which is what the client speaks; a Valkey server is the
# intended deployment and is selected by its URL, so that the features only Valkey
# provides stay reachable. Enable it with `bundle config set --local with redis`.
group :redis, optional: true do
  gem "redis-client"
end

# Optional Aerospike store for the live statistics. Enable it with
# `bundle config set --local with aerospike`.
group :aerospike, optional: true do
  gem "aerospike"
end

# Optional SQLite adapter for the message database. Enable it with
# `bundle config set --local with sqlite`.
group :sqlite, optional: true do
  gem "sqlite3"
end

# Optional S3-compatible blob store backend. Enable it with
# `bundle config set --local with s3`.
group :s3, optional: true do
  gem "aws-sdk-s3"
end

# Optional ACME client used to issue and renew the certificates which the MTA-STS
# policy hosts are served from. Enable it with `bundle config set --local with acme`.
group :acme, optional: true do
  gem "acme-client"
end

# Optional distributed key-value store for message bodies, shared by every node.
# Enable it with `bundle config set --local with foundationdb`.
group :foundationdb, optional: true do
  gem "fdb"
end
