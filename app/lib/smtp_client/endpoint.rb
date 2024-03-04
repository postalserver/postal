# frozen_string_literal: true

module SMTPClient
  class Endpoint

    class SMTPSessionNotStartedError < StandardError
    end

    attr_reader :server
    attr_reader :ip_address
    attr_accessor :smtp_client

    # @param server [Server] the server that this IP address is for
    # @param ip_address [String] the IP address
    def initialize(server, ip_address)
      @server = server
      @ip_address = ip_address
    end

    # Return a description of this server with its IP address
    #
    # @return [String]
    def description
      "#{@ip_address}:#{@server.port} (#{@server.hostname})"
    end

    # Return a string representation of this server
    #
    # @return [String]
    def to_s
      description
    end

    # Return true if this is an IPv6 address
    #
    # @return [Boolean]
    def ipv6?
      @ip_address.include?(":")
    end

    # Return true if this is an IPv4 address
    #
    # @return [Boolean]
    def ipv4?
      !ipv6?
    end

    # Start a new SMTP session and store the client with this server for future use as needed
    #
    # @param source_ip_address [IPAddress] the IP address to use as the source address for the connection
    # @param allow_ssl [Boolean] whether to allow SSL for this connection, if false SSL mode is ignored
    #
    # @return [Net::SMTP]
    def start_smtp_session(source_ip_address: nil, allow_ssl: true)
      @smtp_client = Net::SMTP.new(@ip_address, @server.port)
      @smtp_client.open_timeout = Postal::Config.smtp_client.open_timeout
      @smtp_client.read_timeout = Postal::Config.smtp_client.read_timeout
      @smtp_client.tls_hostname = @server.hostname

      if source_ip_address
        @source_ip_address = source_ip_address
      end

      if @source_ip_address
        @smtp_client.source_address = ipv6? ? @source_ip_address.ipv6 : @source_ip_address.ipv4
      end

      if allow_ssl
        case @server.ssl_mode
        when SSLModes::AUTO
          @smtp_client.enable_starttls_auto(self.class.ssl_context_without_verify)
        when SSLModes::STARTTLS
          @smtp_client.enable_starttls(self.class.ssl_context_with_verify)
        when SSLModes::TLS
          @smtp_client.enable_tls(self.class.ssl_context_with_verify)
        else
          @smtp_client.disable_starttls
          @smtp_client.disable_tls
        end
      else
        @smtp_client.disable_starttls
        @smtp_client.disable_tls
      end

      @smtp_client.start(@source_ip_address ? @source_ip_address.hostname : self.class.default_helo_hostname)

      @smtp_client
    end

    # Send a message to the current SMTP session (or create one if there isn't one for this endpoint).
    # If sending messsage encouters some connection errors, retry again after re-establishing the SMTP
    # session.
    #
    # @param raw_message [String] the raw message to send
    # @param mail_from [String] the MAIL FROM address
    # @param rcpt_to [String] the RCPT TO address
    # @param retry_on_connection_error [Boolean] whether to retry the connection if there is a connection error
    #
    # @return [void]
    def send_message(raw_message, mail_from, rcpt_to, retry_on_connection_error: true)
      raise SMTPSessionNotStartedError if @smtp_client.nil? || (@smtp_client && !@smtp_client.started?)

      @smtp_client.rset_errors
      @smtp_client.send_message(raw_message, mail_from, [rcpt_to])
    rescue Errno::ECONNRESET, Errno::EPIPE, OpenSSL::SSL::SSLError
      if retry_on_connection_error
        finish_smtp_session
        start_smtp_session
        return send_message(raw_message, mail_from, rcpt_to, retry_on_connection_error: false)
      end

      raise
    end

    # Reset the current SMTP session for this server if possible otherwise
    # finish the session
    #
    # @return [void]
    def reset_smtp_session
      @smtp_client&.rset
    rescue StandardError
      finish_smtp_session
    end

    # Finish the current SMTP session for this server if possible.
    #
    # @return [void]
    def finish_smtp_session
      @smtp_client&.finish
    rescue StandardError
      nil
    ensure
      @smtp_client = nil
    end

    class << self

      # Return the default HELO hostname to present to SMTP servers that
      # we connect to
      #
      # @return [String]
      def default_helo_hostname
        Postal::Config.dns.helo_hostname ||
          Postal::Config.postal.smtp_hostname ||
          "localhost"
      end

      def ssl_context_with_verify
        @ssl_context_with_verify ||= begin
          c = OpenSSL::SSL::SSLContext.new
          c.verify_mode = OpenSSL::SSL::VERIFY_PEER
          c.cert_store = OpenSSL::X509::Store.new
          c.cert_store.set_default_paths
          c
        end
      end

      def ssl_context_without_verify
        @ssl_context_without_verify ||= begin
          c = OpenSSL::SSL::SSLContext.new
          c.verify_mode = OpenSSL::SSL::VERIFY_NONE
          c
        end
      end

    end

  end
end
