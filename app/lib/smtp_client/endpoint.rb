# frozen_string_literal: true

module SMTPClient
  class Endpoint

    class SMTPSessionNotStartedError < StandardError
    end

    class AuthenticationNotSupportedError < StandardError
    end

    class MessageTooLargeError < StandardError
    end

    attr_reader :server
    attr_reader :ip_address
    attr_accessor :smtp_client

    # @param server [Server] the server that this IP address is for
    # @param ip_address [String] the IP address
    def initialize(server, ip_address)
      @server = server
      @ip_address = ip_address
      @tls_fallback_attempted = false
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
      authenticate_smtp_session

      @smtp_client
    rescue OpenSSL::SSL::SSLError => e
      raise unless opportunistic_tls_fallback?(allow_ssl)

      # A server which advertises STARTTLS and then cannot complete a handshake
      # is a failure mode that exists in the wild. For an opportunistic endpoint
      # the message is more useful delivered in the clear than not delivered, so
      # the session is rebuilt without TLS once.
      Postal.logger.warn "#{description}: TLS handshake failed (#{e.class}: #{e.message}). " \
                         "Retrying without encryption because this endpoint's SSL mode is Auto."
      @tls_fallback_attempted = true
      start_smtp_session(source_ip_address: source_ip_address, allow_ssl: false)
    end

    # Whether a failed TLS handshake should be retried without encryption.
    #
    # Only endpoints in Auto mode are downgraded: they are opportunistic to
    # begin with, whereas an endpoint which explicitly asks for STARTTLS or TLS
    # is never allowed to fall back. A given session is downgraded at most once.
    #
    # @return [Boolean]
    def opportunistic_tls_fallback?(allow_ssl)
      allow_ssl && @server.ssl_mode == SSLModes::AUTO && !@tls_fallback_attempted
    end

    # Authenticate with this server if it has been given credentials.
    #
    # Net::SMTP completes the handshake, including STARTTLS where the server
    # offers it, before this runs, so a credential is not offered before the
    # connection is encrypted. A server which offers no encryption is still
    # authenticated, because an explicit local relay on a trusted link is a
    # legitimate configuration, but it is warned about: the credential is
    # readable on the wire for the length of that session.
    #
    # @return [void]
    def authenticate_smtp_session
      return unless @server.authenticate?

      type = @server.authentication_type(@smtp_client)

      if type.nil?
        raise AuthenticationNotSupportedError,
              "#{description} was given credentials but does not advertise an authentication mechanism"
      end

      unless @smtp_client.tls?
        Postal.logger.warn "#{description}: authenticating over an unencrypted connection"
      end

      @smtp_client.authenticate(@server.username, @server.password, type)
    end

    # The largest message this server will accept, in bytes, or nil when it
    # publishes no limit.
    #
    # RFC 1870 gives the SIZE keyword in the EHLO reply and defines a value of
    # zero as "the server publishes no fixed maximum", so a zero is treated the
    # same as an absent keyword: the server will not refuse on size.
    #
    # @return [Integer, nil]
    def message_size_limit
      advertised = @smtp_client&.capabilities&.[]("SIZE")&.first
      return nil if advertised.nil?

      limit = advertised.to_i
      limit.positive? ? limit : nil
    end

    # The number of bytes this message will occupy in the transfer.
    #
    # RFC 1870 counts the message as it is transmitted: line endings are CRLF, a
    # line which begins with a dot is sent with that dot doubled, and the dot
    # which ends the data is not counted. Counting the bytes of the raw message
    # would under-report every message of more than one line, and a client which
    # under-reports is still refused, having paid for the transfer.
    #
    # @param raw_message [String]
    # @return [Integer]
    def self.transmitted_size(raw_message)
      raw_message.each_line.sum do |line|
        content = line.chomp
        content.bytesize + 2 + (content.start_with?(".") ? 1 : 0)
      end
    end

    # Refuse a message which this server has already said it will not accept,
    # rather than transferring it and being refused at the end of it.
    #
    # @param raw_message [String]
    # @return [void]
    def refuse_oversized_message(raw_message)
      limit = message_size_limit
      return if limit.nil?

      size = self.class.transmitted_size(raw_message)
      return if size <= limit

      raise MessageTooLargeError,
            "#{description} accepts messages of up to #{limit} bytes but this one is #{size} bytes"
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

      refuse_oversized_message(raw_message)

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
          Postal::TLS.apply_version_limits(c, min: Postal::Config.smtp_client.minimum_tls_version)
          c
        end
      end

      def ssl_context_without_verify
        @ssl_context_without_verify ||= begin
          c = OpenSSL::SSL::SSLContext.new
          c.verify_mode = OpenSSL::SSL::VERIFY_NONE
          Postal::TLS.apply_version_limits(c, min: Postal::Config.smtp_client.minimum_tls_version)
          c
        end
      end

    end

  end
end
