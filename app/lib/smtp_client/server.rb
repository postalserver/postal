# frozen_string_literal: true

module SMTPClient
  class Server

    attr_reader :hostname
    attr_reader :port
    attr_accessor :ssl_mode

    def initialize(hostname, port: 25, ssl_mode: SSLModes::AUTO)
      @hostname = hostname
      @port = port
      @ssl_mode = ssl_mode
    end

    # Return all IP addresses for this server by resolving its hostname.
    #
    # The order/selection depends on the configured smtp_client.address_preference:
    # the preferred family is returned first, the other family is appended when the
    # preference allows a fallback, and only the preferred family is returned for
    # the strict "only" values.
    #
    # @return [Array<SMTPClient::Endpoint>]
    def endpoints
      ipv6_endpoints = DNSResolver.local.aaaa(@hostname).map { |ip| Endpoint.new(self, ip) }
      ipv4_endpoints = DNSResolver.local.a(@hostname).map { |ip| Endpoint.new(self, ip) }

      if AddressPreferences.prefer_ipv4?
        ordered_endpoints(ipv4_endpoints, ipv6_endpoints)
      else
        ordered_endpoints(ipv6_endpoints, ipv4_endpoints)
      end
    end

    private

    # Return the preferred endpoints first, appending the other family only when
    # a fallback is allowed.
    #
    # @param preferred [Array<SMTPClient::Endpoint>]
    # @param others [Array<SMTPClient::Endpoint>]
    # @return [Array<SMTPClient::Endpoint>]
    def ordered_endpoints(preferred, others)
      AddressPreferences.fallback? ? preferred + others : preferred
    end

  end
end
