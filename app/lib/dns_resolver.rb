# frozen_string_literal: true

require "resolv"

class DNSResolver

  attr_reader :nameservers
  attr_reader :timeout

  def initialize(nameservers: nil, timeout: 5)
    @nameservers = nameservers
    @timeout = timeout
  end

  # Return all A records for the given name
  #
  # @param [String] name
  # @return [Array<String>]
  def a(name)
    dns do |dns|
      dns.getresources(name, Resolv::DNS::Resource::IN::A).map do |s|
        s.address.to_s
      end
    end
  end

  # Return all AAAA records for the given name
  #
  # @param [String] name
  # @return [Array<String>]
  def aaaa(name)
    dns do |dns|
      dns.getresources(name, Resolv::DNS::Resource::IN::AAAA).map do |s|
        s.address.to_s
      end
    end
  end

  # Return all TXT records for the given name
  #
  # @param [String] name
  # @return [Array<String>]
  def txt(name)
    dns do |dns|
      dns.getresources(name, Resolv::DNS::Resource::IN::TXT).map do |s|
        s.data.to_s.strip
      end
    end
  end

  # Return all CNAME records for the given name
  #
  # @param [String] name
  # @return [Array<String>]
  def cname(name)
    dns do |dns|
      dns.getresources(name, Resolv::DNS::Resource::IN::CNAME).map do |s|
        s.name.to_s.downcase
      end
    end
  end

  # Return all MX records for the given name
  #
  # @param [String] name
  # @return [Array<Array<Integer, String>>]
  def mx(name)
    dns do |dns|
      records = dns.getresources(name, Resolv::DNS::Resource::IN::MX).map do |m|
        [m.preference.to_i, m.exchange.to_s]
      end
      records.sort do |a, b|
        if a[0] == b[0]
          [-1, 1].sample
        else
          a[0] <=> b[0]
        end
      end
    end
  end

  # Return the effective nameserver names for a given domain name.
  #
  # @param [String] name
  # @return [Array<String>]
  def effective_ns(name)
    records = []
    dns do |dns|
      parts = name.split(".")
      (parts.size - 1).times do |n|
        d = parts[n, parts.size - n + 1].join(".")

        records = dns.getresources(d, Resolv::DNS::Resource::IN::NS).map do |s|
          s.name.to_s
        end

        break if records.present?
      end
    end

    records
  end

  # Return the hostname for a given IP address.
  # Returns the IP address itself if no hostname can be determined.
  #
  # @param [String] ip_address
  # @return [String]
  def ip_to_hostname(ip_address)
    dns do |dns|
      dns.getname(ip_address)&.to_s
    end
  rescue Resolv::ResolvError
    ip_address
  end

  private

  def dns
    kwargs = @nameservers ? { nameserver: @nameservers } : {}
    Resolv::DNS.open(**kwargs) do |dns|
      dns.timeouts = [@timeout, @timeout / 2]
      yield dns
    end
  end

  class << self

    # Return a resolver which will use the nameservers for the given domain
    #
    # @param [String] name
    # @return [DNSResolver]
    def for_domain(name)
      resolver = new
      nameservers = resolver.effective_ns(name)
      ips = nameservers.map do |ns|
        resolver.a(ns)
      end.flatten.uniq
      new(nameservers: ips)
    end

    # Return a local resolver to use for lookups
    #
    # @return [DNSResolver]
    def local
      @local ||= new
    end

  end

end
