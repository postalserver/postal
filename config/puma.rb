# frozen_string_literal: true

require_relative "../lib/postal/config"

threads_count = Postal::Config.web_server.max_threads
threads         threads_count, threads_count
bind_address  = ENV.fetch("BIND_ADDRESS", Postal::Config.web_server.default_bind_address)
bind_port     = ENV.fetch("PORT", Postal::Config.web_server.default_port)
bind            "tcp://#{bind_address}:#{bind_port}"
environment     Postal::Config.rails.environment || "development"
prune_bundler
quiet false
