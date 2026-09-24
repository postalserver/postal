# frozen_string_literal: true

module SMTPClient
  class Server

    # The SASL mechanisms a relay may be told to use. Each one is implemented
    # by Net::SMTP, so naming one here selects its authenticator.
    AUTHENTICATION_TYPES = {
      "plain" => :plain,
      "login" => :login,
      "cram_md5" => :cram_md5
    }.freeze

    attr_reader :hostname
    attr_reader :port
    attr_reader :username
    attr_reader :password
    attr_reader :authentication
    attr_accessor :ssl_mode

    # @param hostname [String] the hostname to deliver to
    # @param port [Integer] the port to connect to
    # @param ssl_mode [String] how to negotiate encryption
    # @param username [String, nil] the identity to authenticate as, if any
    # @param password [String, nil] the secret that goes with the identity
    # @param authentication [String, nil] the mechanism to authenticate with, or
    #   nil to use the strongest the server advertises
    def initialize(hostname, port: 25, ssl_mode: SSLModes::AUTO, username: nil, password: nil,
                   authentication: nil)
      @hostname = hostname
      @port = port
      @ssl_mode = ssl_mode
      @username = username
      @password = password
      @authentication = authentication
    end

    # Return true if this server is configured to authenticate
    #
    # @return [Boolean]
    def authenticate?
      @username.present?
    end

    # Return the SASL mechanism to authenticate with.
    #
    # A mechanism named on the relay is used as given, so an operator can work
    # around a relay which advertises something it cannot complete. When none is
    # named, the strongest mechanism the server offers is chosen, which keeps a
    # relay reachable whether it implements CRAM-MD5, PLAIN, or only the older
    # LOGIN.
    #
    # @param smtp_client [Net::SMTP] a client whose session has been started
    # @return [Symbol, nil] nil if the server offers no mechanism at all
    def authentication_type(smtp_client)
      return configured_authentication_type if @authentication

      return :cram_md5 if smtp_client.capable_cram_md5_auth?
      return :plain if smtp_client.capable_plain_auth?
      return :login if smtp_client.capable_login_auth?

      nil
    end

    # Return all IP addresses for this server by resolving its hostname.
    # IPv6 addresses will be returned first.
    #
    # @return [Array<SMTPClient::Endpoint>]
    def endpoints
      ips = []

      DNSResolver.local.aaaa(@hostname).each do |ip|
        ips << Endpoint.new(self, ip)
      end

      DNSResolver.local.a(@hostname).each do |ip|
        ips << Endpoint.new(self, ip)
      end

      ips
    end

    private

    def configured_authentication_type
      AUTHENTICATION_TYPES.fetch(@authentication.to_s.downcase) do
        raise ArgumentError, "The auth on an SMTP relay must be one of " \
                             "#{AUTHENTICATION_TYPES.keys.join(', ')}, not #{@authentication.inspect}"
      end
    end

  end
end
