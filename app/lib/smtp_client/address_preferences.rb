# frozen_string_literal: true

module SMTPClient
  # Controls which IP address family we use for outgoing SMTP connections when a
  # remote host publishes both AAAA (IPv6) and A (IPv4) records.
  #
  # Two models are supported, selected by smtp_client.address_preference:
  #
  #   * prefer (ipv6, ipv4) - the named family is tried first but the other
  #     family is still used as a fallback if it cannot be reached.
  #   * only (ipv6_only, ipv4_only) - only the named family is ever used.
  module AddressPreferences

    IPV6 = "ipv6"
    IPV4 = "ipv4"
    IPV6_ONLY = "ipv6_only"
    IPV4_ONLY = "ipv4_only"

    ALL = [IPV6, IPV4, IPV6_ONLY, IPV4_ONLY].freeze
    DEFAULT = IPV6

    class << self

      # Return the configured address preference. Unknown values fall back to
      # the default (and log a warning, once) rather than breaking deliveries.
      #
      # @return [String] one of the constants above
      def current
        value = Postal::Config.smtp_client.address_preference.to_s.strip.downcase
        return value if ALL.include?(value)

        warn_about_invalid_value(value)
        DEFAULT
      end

      # Should IPv4 be tried before IPv6?
      #
      # @return [Boolean]
      def prefer_ipv4?
        current.start_with?(IPV4)
      end

      # Should the other family be used when the preferred one cannot be
      # connected to? False in the strict "only" modes.
      #
      # @return [Boolean]
      def fallback?
        !current.end_with?("_only")
      end

      private

      def warn_about_invalid_value(value)
        return if @warned_about == value

        @warned_about = value
        Postal.logger.warn "Invalid smtp_client.address_preference '#{value}' " \
                           "(expected one of: #{ALL.join(', ')}). Using '#{DEFAULT}'."
      end

    end

  end
end
