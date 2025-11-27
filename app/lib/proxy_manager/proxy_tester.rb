# frozen_string_literal: true

module ProxyManager
  class ProxyTester

    def self.test(ip_address)
      new(ip_address).test
    end

    def initialize(ip_address)
      @ip_address = ip_address
    end

    def test
      unless @ip_address.proxy_configured?
        return {
          success: false,
          message: "Proxy is not configured for this IP address"
        }
      end

      begin
        result = test_socks_connection
        @ip_address.update(
          proxy_last_tested_at: Time.now,
          proxy_last_test_result: result[:message],
          proxy_status: result[:success] ? "active" : "failed"
        )
        result
      rescue StandardError => e
        error_result = {
          success: false,
          message: "Test failed: #{e.message}"
        }
        @ip_address.update(
          proxy_last_tested_at: Time.now,
          proxy_last_test_result: error_result[:message],
          proxy_status: "failed"
        )
        error_result
      end
    end

    private

    def test_socks_connection
      require "socksify"
      require "socket"
      require "timeout"

      # Configure SOCKS proxy
      TCPSocket.socks_server = @ip_address.proxy_host
      TCPSocket.socks_port = @ip_address.proxy_port

      if @ip_address.proxy_username.present?
        TCPSocket.socks_username = @ip_address.proxy_username
        TCPSocket.socks_password = @ip_address.proxy_password
      end

      # Test 1: Basic connectivity
      Timeout.timeout(10) do
        socket = TCPSocket.new(@ip_address.proxy_host, @ip_address.proxy_port)
        socket.close
      end

      # Test 2: Try to connect through SOCKS to a test server
      Timeout.timeout(15) do
        test_socket = TCPSocket.new("google.com", 80)
        test_socket.close
      end

      # Test 3: Get external IP через прокси
      external_ip = get_external_ip_through_proxy

      {
        success: true,
        message: "Proxy connection successful! External IP: #{external_ip}",
        external_ip: external_ip
      }
    rescue Errno::ECONNREFUSED
      {
        success: false,
        message: "Connection refused. Is the proxy server running on #{@ip_address.proxy_host}:#{@ip_address.proxy_port}?"
      }
    rescue Errno::ETIMEDOUT, Timeout::Error
      {
        success: false,
        message: "Connection timeout. Check firewall and network connectivity."
      }
    rescue SocketError => e
      {
        success: false,
        message: "DNS or network error: #{e.message}"
      }
    rescue StandardError => e
      {
        success: false,
        message: "Error: #{e.class} - #{e.message}"
      }
    ensure
      # Reset SOCKS settings
      TCPSocket.socks_server = nil
      TCPSocket.socks_port = nil
    end

    def get_external_ip_through_proxy
      require "net/http"
      require "socksify/http"

      TCPSocket.socks_server = @ip_address.proxy_host
      TCPSocket.socks_port = @ip_address.proxy_port

      if @ip_address.proxy_username.present?
        TCPSocket.socks_username = @ip_address.proxy_username
        TCPSocket.socks_password = @ip_address.proxy_password
      end

      uri = URI("http://ifconfig.me/ip")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 10
      http.read_timeout = 10

      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)

      if response.code == "200"
        response.body.strip
      else
        "unknown"
      end
    rescue StandardError
      "unknown"
    ensure
      TCPSocket.socks_server = nil
      TCPSocket.socks_port = nil
    end

  end
end
