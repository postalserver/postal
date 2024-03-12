# frozen_string_literal: true

require "resolv"

class DNSResolver

  class LocalResolversUnavailableError < StandardError
  end

  attr_reader :nameservers
  attr_reader :timeout

  def initialize(nameservers)
    @nameservers = nameservers
  end

  # Return all A records for the given name
  #
  # @param [String] name
  # @return [Array<String>]
  def a(name, **options)
    get_resources(name, Resolv::DNS::Resource::IN::A, **options).map do |s|
      s.address.to_s
    end
  end

  # Return all AAAA records for the given name
  #
  # @param [String] name
  # @return [Array<String>]
  def aaaa(name, **options)
    get_resources(name, Resolv::DNS::Resource::IN::AAAA, **options).map do |s|
      s.address.to_s
    end
  end

  # Return all TXT records for the given name
  #
  # @param [String] name
  # @return [Array<String>]
  def txt(name, **options)
    get_resources(name, Resolv::DNS::Resource::IN::TXT, **options).map do |s|
      s.data.to_s.strip
    end
  end

  # Return all CNAME records for the given name
  #
  # @param [String] name
  # @return [Array<String>]
  def cname(name, **options)
    get_resources(name, Resolv::DNS::Resource::IN::CNAME, **options).map do |s|
      s.name.to_s.downcase
    end
  end

  # Return all MX records for the given name
  #
  # @param [String] name
  # @return [Array<Array<Integer, String>>]
  def mx(name, **options)
    records = get_resources(name, Resolv::DNS::Resource::IN::MX, **options).map do |m|
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

  # Return the effective nameserver names for a given domain name.
  #
  # @param [String] name
  # @return [Array<String>]
  def effective_ns(name, **options)
    records = []
    parts = name.split(".")
    (parts.size - 1).times do |n|
      d = parts[n, parts.size - n + 1].join(".")

      records = get_resources(d, Resolv::DNS::Resource::IN::NS, **options).map do |s|
        s.name.to_s
      end

      break if records.present?
    end

    records
  end

  # Return the hostname for a given IP address.
  # Returns the IP address itself if no hostname can be determined.
  #
  # @param [String] ip_address
  # @return [String]
  def ip_to_hostname(ip_address, **options)
    dns(**options) do |dns|
      dns.getname(ip_address)&.to_s
    end
  rescue Resolv::ResolvError => e
    raise if e.message =~ /timeout/ && options[:raise_timeout_errors]

    ip_address
  end

  private

  def dns(raise_timeout_errors: false)
    Resolv::DNS.open(nameserver: @nameservers,
                     raise_timeout_errors: raise_timeout_errors) do |dns|
      dns.timeouts = [
        Postal::Config.dns.timeout,
        Postal::Config.dns.timeout / 2,
        Postal::Config.dns.timeout / 2,
      ]
      yield dns
    end
  end

  def get_resources(name, type, **options)
    encoded_name = DomainName::Punycode.encode_hostname(name)
    dns(**options) do |dns|
      dns.getresources(encoded_name, type)
    end
  end

  class << self

    # Return a resolver which will use the nameservers for the given domain
    #
    # @param [String] name
    # @return [DNSResolver]
    def for_domain(name)
      nameservers = local.effective_ns(name)
      ips = nameservers.map do |ns|
        local.a(ns)
      end.flatten.uniq
      new(ips)
    end

    # Return a local resolver to use for lookups
    #
    # @return [DNSResolver]
    def local
      @local ||= begin
        resolv_conf_path = Postal::Config.dns.resolv_conf_path
        raise LocalResolversUnavailableError, "No resolver config found at #{resolv_conf_path}" unless File.file?(resolv_conf_path)

        resolv_conf = Resolv::DNS::Config.parse_resolv_conf(resolv_conf_path)
        if resolv_conf.nil? || resolv_conf[:nameserver].nil? || resolv_conf[:nameserver].empty?
          raise LocalResolversUnavailableError, "Could not find nameservers in #{resolv_conf_path}"
        end

        new(resolv_conf[:nameserver])
      end
    end

  end

end
