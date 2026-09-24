# frozen_string_literal: true

# The session policy is a decision rather than a library default: how long a
# session may sit unused before it is refused, how long a remembered login lasts,
# and how long a session may act without confirming a password again.
#
# The shipped values are the ones Authie itself defaults to, so this changes
# nothing on its own. It exists so that the policy is stated here, can be set per
# deployment, and does not silently move when the library changes its mind.
Authie.configure do |config|
  config.session_inactivity_timeout = Postal::Config.sessions.inactivity_timeout.seconds
  config.persistent_session_length = Postal::Config.sessions.persistent_length.seconds
  config.sudo_session_timeout = Postal::Config.sessions.sudo_timeout.seconds
end
