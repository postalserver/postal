# frozen_string_literal: true

# Rack::Request.ip_filter, which this used, is gone in Rack 3. The RemoteIp
# middleware reads config.action_dispatch.trusted_proxies instead. Note that a
# custom list replaces the middleware's defaults, so the loopback ranges the
# old filter matched are carried over explicitly.
Rails.application.config.action_dispatch.trusted_proxies = [
  IPAddr.new("127.0.0.0/8"),
  IPAddr.new("::1/128"),
  IPAddr.new("fd00::/8"),
  *Array(Postal::Config.postal.trusted_proxies),
]
