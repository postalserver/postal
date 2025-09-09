# frozen_string_literal: true
require 'ipaddr'

module SMTPClient
  class Server

    attr_reader :hostname
    attr_reader :port
    attr_accessor :ssl_mode
    attr_reader :username
    attr_reader :password
    attr_reader :authentication

    def initialize(hostname, port: 25, ssl_mode: SSLModes::AUTO, username: nil, password: nil, authentication: nil)
      @hostname = hostname
      @port = port
      @ssl_mode = ssl_mode
      @username = username
      @password = password
      @authentication = authentication

      # Debug log
      puts "=== SMTPClient::Server Initialized ==="
      puts "hostname: #{@hostname}"
      puts "port: #{@port}"
      puts "ssl_mode: #{@ssl_mode}"
      puts "username: #{@username.inspect}"
      puts "username decoded: #{@username ? CGI.unescape(@username) : nil}"
      puts "password: #{@password ? '****' : nil}"
      puts "authentication: #{@authentication}"
      puts "===================================="
    end

    # Return all IP addresses for this server by resolving its hostname.
    # IPv6 addresses will be returned first.
    #
    # @return [Array<SMTPClient::Endpoint>]
    def endpoints
      ips = []

      # Vérifier si @hostname est une IP
      is_ip = false
      begin
        IPAddr.new(@hostname)
        is_ip = true
      rescue ArgumentError
        is_ip = false
      end

      if is_ip
        # @hostname est une IP
        ips << Endpoint.new(self, @hostname)
      else
        # @hostname est un nom de domaine => faire résolution DNS
        DNSResolver.local.aaaa(@hostname).each do |ip|
          puts "Adding AAAA endpoint: #{ip}"
          ips << Endpoint.new(self, ip)
        end

        DNSResolver.local.a(@hostname).each do |ip|
          puts "Adding A endpoint: #{ip}"
          ips << Endpoint.new(self, ip)
        end
      end

      puts "Total endpoints for #{@hostname}: #{ips.size}"
      ips
    end
  end
end
