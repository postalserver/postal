# frozen_string_literal: true

require "net/http"
require "uri"

module SMTPClient
  #
  # MTA-STS (RFC 8461): the policy a destination domain publishes to say that
  # its mail must be delivered over verified TLS, and to say which hosts may
  # deliver it.
  #
  # A policy is discovered through a TXT record and then fetched over HTTPS. The
  # TXT lookup is cheap and happens on every delivery, so a change of policy is
  # noticed at once; the HTTPS fetch only happens when the id in that record
  # changes or the cached policy has passed the max_age it declared.
  #
  # A policy which cannot be retrieved is treated as no policy at all. MTA-STS
  # is a signal that a domain wants to be protected, not a reason to stop
  # delivering its mail, so failing to fetch a policy never blocks a delivery on
  # its own; only a policy which has been read and says "enforce" does that.
  #
  module MTASts

    DNS_PREFIX = "_mta-sts"
    POLICY_URL = "https://mta-sts.%s/.well-known/mta-sts.txt"
    FETCH_TIMEOUT = 5
    # How long an absent record or a failed fetch is remembered before the
    # domain is looked at again.
    NEGATIVE_TTL = 300
    MIN_MAX_AGE = 60
    MAX_MAX_AGE = 31_557_600

    class << self

      # Return the policy which applies to the given domain.
      #
      # @param domain [String]
      # @return [Policy, nil] nil when the domain publishes no usable policy
      def policy_for(domain)
        return nil unless Postal::Config.smtp_client.mta_sts?

        domain = domain.to_s.downcase
        id = dns_policy_id(domain)

        if id.nil?
          remember(domain, nil, id: nil, ttl: NEGATIVE_TTL)
          return nil
        end

        cached = cached_policy(domain, id)
        return cached if cached

        policy = fetch_policy(domain)
        remember(domain, policy, id: id, ttl: policy ? policy.max_age : NEGATIVE_TTL)
        policy
      end

      # Forget every cached policy.
      #
      # @return [void]
      def clear!
        mutex.synchronize { cache.clear }
      end

      private

      # A cached policy, if one is held for this id and has not expired. A nil
      # policy is cached too, so a domain without a record is not looked up over
      # and over, but it is only returned as "no policy" either way.
      def cached_policy(domain, id)
        entry = cache[domain]
        return nil if entry.nil?
        return nil unless entry[:id] == id
        return nil unless entry[:expires_at] > Time.now

        entry[:policy] || nil
      end

      def remember(domain, policy, id:, ttl:)
        mutex.synchronize do
          cache[domain] = { policy: policy, id: id, expires_at: Time.now + ttl }
        end
      end

      def cache
        @cache ||= {}
      end

      def mutex
        @mutex ||= Mutex.new
      end

      # The id of the domain's MTA-STS record, or nil when it publishes none.
      #
      # @param domain [String]
      # @return [String, nil]
      def dns_policy_id(domain)
        DNSResolver.local.txt("#{DNS_PREFIX}.#{domain}").each do |record|
          next unless record.match?(/\Av=STSv1\s*;/i)

          id = record[/\bid=([^;\s]+)/i, 1]
          return id.downcase if id
        end

        nil
      rescue StandardError => e
        Postal.logger.warn "MTA-STS: could not look up _mta-sts.#{domain} (#{e.class}: #{e.message})"
        nil
      end

      def fetch_policy(domain)
        text = fetch(domain)
        return nil if text.nil?

        policy = Policy.parse(text)
        if policy.nil?
          Postal.logger.warn "MTA-STS: #{domain} publishes a policy which cannot be used; ignoring it"
        end
        policy
      end

      # Fetch the policy over HTTPS, verifying the certificate presented by the
      # policy host. A policy served over a connection which cannot be verified
      # is worth no more than one served in the clear, so it is not accepted.
      #
      # @param domain [String]
      # @return [String, nil]
      def fetch(domain)
        uri = URI.parse(format(POLICY_URL, domain))
        http = Net::HTTP.new(uri.host, uri.port)
        begin
          http.ipaddr = Postal::HTTP::AddressGuard.safe_connect_address(uri.host)
        rescue Postal::HTTP::UnresolvableError
          # The host does not resolve (or no resolver is reachable here). Leave
          # the connection unpinned: the fetch below fails the same way an
          # unguarded one would, and that failure is already handled.
          nil
        rescue Postal::HTTP::BlockedDestinationError
          Postal.logger.warn "MTA-STS: #{domain} resolves to a destination which will not be contacted"
          return nil
        end
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.cert_store = OpenSSL::X509::Store.new
        http.cert_store.set_default_paths
        http.open_timeout = FETCH_TIMEOUT
        http.read_timeout = FETCH_TIMEOUT

        response = http.get(uri.request_uri)
        return response.body if response.is_a?(Net::HTTPSuccess)

        Postal.logger.warn "MTA-STS: #{domain} answered #{response.code} when asked for its policy"
        nil
      rescue StandardError => e
        Postal.logger.warn "MTA-STS: could not fetch the policy for #{domain} (#{e.class}: #{e.message})"
        nil
      end

    end

    # A policy as published by a domain.
    class Policy

      MODES = %w[enforce testing none].freeze

      attr_reader :mode
      attr_reader :max_age
      attr_reader :mx

      # Parse a policy from the text served at the well-known location.
      #
      # @param text [String]
      # @return [Policy, nil] nil when the text is not a policy which can be used
      def self.parse(text)
        version = nil
        mode = nil
        max_age = nil
        mx = []

        text.to_s.each_line do |line|
          key, value = line.strip.split(":", 2)
          next if value.nil?

          value = value.strip
          case key.strip.downcase
          when "version" then version = value
          when "mode" then mode = value.downcase
          when "max_age" then max_age = value.to_i
          when "mx" then mx << value.downcase.chomp(".")
          end
        end

        return nil unless version.to_s.casecmp("STSv1").zero?
        return nil unless MODES.include?(mode)
        return nil unless max_age&.positive?
        # A policy which names no host leaves nowhere to deliver to, which
        # cannot be what the domain intends, so it is not acted upon.
        return nil if mx.empty? && mode != "none"

        new(mode: mode, max_age: max_age.clamp(MIN_MAX_AGE, MAX_MAX_AGE), hosts: mx)
      end

      def initialize(mode:, max_age:, hosts:)
        @mode = mode
        @max_age = max_age
        @mx = hosts
      end

      # Whether the domain requires its mail to be delivered over verified TLS to
      # one of the hosts it lists.
      #
      # @return [Boolean]
      def enforce?
        @mode == "enforce"
      end

      # Whether the given host is one of the hosts this policy lists.
      #
      # @param hostname [String]
      # @return [Boolean]
      def publishes_mx?(hostname)
        @mx.include?(hostname.to_s.downcase.chomp("."))
      end

    end

  end
end
