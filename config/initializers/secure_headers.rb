# frozen_string_literal: true

SecureHeaders::Configuration.default do |config|
  config.hsts = SecureHeaders::OPT_OUT

  # The XSS auditor is deprecated in every current browser and its filtering
  # heuristics have themselves been a source of vulnerabilities, so it is turned
  # off explicitly rather than left at the library's default, which enables it.
  config.x_xss_protection = "0"

  config.csp[:default_src] = []
  config.csp[:script_src] = ["'self'"]
  config.csp[:child_src] = ["'self'"]
  config.csp[:connect_src] = ["'self'"]
end
