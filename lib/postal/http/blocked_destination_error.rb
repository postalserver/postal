# frozen_string_literal: true

module Postal
  module HTTP

    # Raised when an outbound request would be sent to an address that is not
    # permitted (a private, loopback, link-local or otherwise reserved address
    # that has not been explicitly allowlisted). Used as an SSRF guard.
    class BlockedDestinationError < StandardError
    end

    # Raised when the destination host cannot be resolved at all. A subclass of
    # the blocked error so existing rescues keep working, but separable for
    # callers which already handle fetch failures and only need the guard to
    # refuse destinations it positively identifies as unsafe.
    class UnresolvableError < BlockedDestinationError
    end

  end
end
