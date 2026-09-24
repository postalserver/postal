# frozen_string_literal: true

# The secret is injected via SECRET_KEY_BASE in config/boot.rb, which flows
# through Rails' own resolution (ENV, then credentials, then a local secret in
# development and test). Assigning into Rails.application.credentials here used
# to be how it was done, but that object is the encrypted credentials file, not
# a general settings bag, and writing to it at boot runs too late for the
# session middleware. Nothing is set here; this file only warns when no secret
# is configured, in which case production refuses to boot rather than running
# with sessions that die on every restart.
unless Postal::Config.rails.secret_key || ENV["SECRET_KEY_BASE"]
  warn "No secret key was specified in the Postal config file. Set rails.secret_key."
end
