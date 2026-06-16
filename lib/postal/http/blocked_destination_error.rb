# frozen_string_literal: true

module Postal
  module HTTP
    # Raised when an outbound request would be sent to an address that is not
    # permitted (a private, loopback, link-local or otherwise reserved address
    # that has not been explicitly allowlisted). Used as an SSRF guard.
    class BlockedDestinationError < StandardError
    end
  end
end
