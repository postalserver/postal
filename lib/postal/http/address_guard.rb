# frozen_string_literal: true

require "ipaddr"
require "resolv"
require "socket"

module Postal
  module HTTP
    # Guards outbound HTTP requests against SSRF by resolving the destination
    # host and refusing to connect to private, loopback, link-local, multicast
    # or otherwise reserved addresses (for example cloud metadata endpoints).
    #
    # Administrators can permit specific destinations by adding hostnames or
    # IP/CIDR ranges to the `postal.allowed_request_destinations` config option.
    class AddressGuard

      # IP ranges that outbound requests are never allowed to reach unless the
      # destination has been explicitly allowlisted.
      BLOCKED_RANGES = [
        # IPv4
        "0.0.0.0/8",        # "this host on this network"
        "10.0.0.0/8",       # RFC1918 private
        "100.64.0.0/10",    # RFC6598 carrier-grade NAT
        "127.0.0.0/8",      # loopback
        "169.254.0.0/16",   # link-local (incl. 169.254.169.254 metadata)
        "172.16.0.0/12",    # RFC1918 private
        "192.0.0.0/24",     # IETF protocol assignments
        "192.168.0.0/16",   # RFC1918 private
        "198.18.0.0/15",    # benchmarking
        "224.0.0.0/4",      # multicast
        "240.0.0.0/4",      # reserved
        # IPv6
        "::/128",           # unspecified
        "::1/128",          # loopback
        "::ffff:0:0/96",    # IPv4-mapped (also re-checked against the v4 list)
        "fc00::/7",         # unique-local
        "fe80::/10",        # link-local
        "ff00::/8", # multicast
      ].map { |range| IPAddr.new(range) }.freeze

      class << self

        # Resolve and validate the given host, returning the IP address the
        # connection should be pinned to (as a string). Pinning the connection
        # to the validated address prevents a DNS-rebinding race between the
        # check here and the actual connection.
        #
        # @param [String] host the hostname or IP literal from the request URL
        # @raise [Postal::HTTP::BlockedDestinationError] if the host cannot be
        #   resolved or any resolved address is not permitted
        # @raise [SocketError] if the host only resolves to addresses whose
        #   family this server cannot reach (e.g. IPv6 with no IPv6 support)
        # @return [String] the validated IP address to connect to
        def safe_connect_address(host)
          new(host).safe_connect_address
        end

        # Whether this server has IPv6 connectivity (a global IPv6 address on
        # one of its interfaces). Memoized as it does not change at runtime.
        def ipv6_supported?
          return @ipv6_supported unless @ipv6_supported.nil?

          @ipv6_supported = local_families.include?(:ipv6)
        end

        # Whether this server has IPv4 connectivity. Defaults to true unless the
        # host clearly only has IPv6, so that a host reporting no global
        # addresses at all (e.g. inside a minimal container) still attempts IPv4
        # as it did before this guard existed.
        def ipv4_supported?
          return @ipv4_supported unless @ipv4_supported.nil?

          families = local_families
          @ipv4_supported = families.include?(:ipv4) || !families.include?(:ipv6)
        end

        private

        def local_families
          families = []
          Socket.ip_address_list.each do |address|
            families << :ipv4 if address.ipv4? && !address.ipv4_loopback?
            families << :ipv6 if address.ipv6? && !address.ipv6_loopback? && !address.ipv6_linklocal?
          end
          families.uniq
        end

      end

      # @param [String] host
      def initialize(host)
        @host = host.to_s
      end

      def safe_connect_address
        if @host.empty?
          raise BlockedDestinationError, "No host was given for the request"
        end

        addresses = resolve
        if addresses.empty?
          raise BlockedDestinationError, "Could not resolve '#{@host}' to any IP address"
        end

        # Reject the whole request if *any* resolved address is blocked. This is
        # checked before the reachability filtering below so that a blocked
        # destination is always reported as such, regardless of which address
        # families this particular server can reach. It also defeats DNS
        # responses that mix a public and a private address to slip past.
        addresses.each do |address|
          next unless blocked?(address)

          raise BlockedDestinationError,
                "Destination '#{@host}' (#{address}) is not permitted"
        end

        # Only connect to an address whose family this server can actually
        # reach. Otherwise we might pin the connection to an IPv6 address on a
        # host without IPv6 connectivity and fail to connect even when a usable
        # IPv4 address was available.
        usable = addresses.select { |address| family_reachable?(address) }
        if usable.empty?
          raise SocketError,
                "'#{@host}' only resolves to addresses this server cannot reach " \
                "(#{addresses.join(', ')})"
        end

        # Prefer IPv4 for predictability; only use IPv6 when it is the only
        # reachable option.
        (usable.find(&:ipv4?) || usable.first).to_s
      end

      private

      # @return [Array<IPAddr>]
      def resolve
        return [IPAddr.new(@host)] if ip_literal?

        Resolv.getaddresses(@host).filter_map do |address|
          IPAddr.new(address)
        rescue IPAddr::InvalidAddressError
          nil
        end
      end

      def ip_literal?
        IPAddr.new(@host)
        true
      rescue IPAddr::InvalidAddressError
        false
      end

      # @param [IPAddr] address
      def family_reachable?(address)
        if address.ipv6? && !address.ipv4_mapped?
          self.class.ipv6_supported?
        else
          self.class.ipv4_supported?
        end
      end

      # @param [IPAddr] address
      def blocked?(address)
        return false if allowlisted?(address)

        # IPv4-mapped IPv6 addresses (::ffff:a.b.c.d) must be checked against the
        # IPv4 rules using the embedded address, otherwise they bypass the list.
        if address.ipv6? && address.ipv4_mapped?
          mapped = address.native
          return true if mapped.ipv4? && BLOCKED_RANGES.any? { |range| range.include?(mapped) }
        end

        BLOCKED_RANGES.any? { |range| range.include?(address) }
      end

      # @param [IPAddr] address
      def allowlisted?(address)
        allowlist.any? do |entry|
          if entry.is_a?(IPAddr)
            entry.include?(address)
          else
            entry.casecmp?(@host)
          end
        end
      end

      # Allowlist entries are kept as strings in config. An entry that parses as
      # an IP/CIDR is matched against the resolved address; anything else is
      # matched against the request hostname (case-insensitively).
      #
      # @return [Array<IPAddr, String>]
      def allowlist
        @allowlist ||= Array(Postal::Config.postal.allowed_request_destinations).map do |entry|
          IPAddr.new(entry.to_s)
        rescue IPAddr::InvalidAddressError
          entry.to_s
        end
      end

    end
  end
end
