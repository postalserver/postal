# frozen_string_literal: true

require "openssl"

module Postal
  #
  # The TLS version names used in configuration, and the one place a version
  # range is applied to a context.
  #
  module TLS

    # TLS 1.3 is only present on builds which have it, so it is added
    # defensively rather than referring to a constant which may not exist. The
    # older versions are referenced directly: they are what the OpenSSL the
    # application runs against provides.
    VERSIONS = {
      "1.0" => OpenSSL::SSL::TLS1_VERSION,
      "1.1" => OpenSSL::SSL::TLS1_1_VERSION,
      "1.2" => OpenSSL::SSL::TLS1_2_VERSION
    }.tap do |versions|
      versions["1.3"] = OpenSSL::SSL::TLS1_3_VERSION if defined?(OpenSSL::SSL::TLS1_3_VERSION)
    end.freeze

    class << self

      #
      # The OpenSSL constant for a configured version name, or nil when no
      # version was configured. An unrecognised name is an error rather than a
      # silent fallback, because a mistyped floor should not quietly leave the
      # context at its default.
      #
      # @param name [String, nil]
      # @return [Integer, nil]
      #
      def version_constant(name)
        return nil if name.nil? || name.to_s.empty?

        VERSIONS[name.to_s] ||
          raise(Postal::Error, "Unknown TLS version '#{name}' (expected one of #{VERSIONS.keys.join(', ')})")
      end

      #
      # Apply a version range to an SSL context.
      #
      # @param context [OpenSSL::SSL::SSLContext]
      # @param min [String, nil] the oldest version to negotiate
      # @param max [String, nil] the newest version to negotiate
      # @return [OpenSSL::SSL::SSLContext]
      #
      def apply_version_limits(context, min: nil, max: nil)
        minimum = version_constant(min)
        maximum = version_constant(max)
        context.min_version = minimum if minimum
        context.max_version = maximum if maximum
        context
      end

    end

  end
end
