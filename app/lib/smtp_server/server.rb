# frozen_string_literal: true

require "ipaddr"
require "nio"

module SMTPServer
  class Server

    include HasMetrics

    # How often the event loop wakes with no work to do so that connections
    # which have gone quiet can be closed.
    IDLE_CHECK_INTERVAL = 10

    class << self

      def tls_private_key
        @tls_private_key ||= OpenSSL::PKey.read(File.read(Postal::Config.smtp_server.tls_private_key_path))
      end

      def tls_certificates
        @tls_certificates ||= begin
          data = File.read(Postal::Config.smtp_server.tls_certificate_path)
          certs = data.scan(/-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----/m)
          certs.map do |c|
            OpenSSL::X509::Certificate.new(c)
          end.freeze
        end
      end

    end

    def initialize(options = {})
      @options = options
      @options[:debug] ||= false
      register_metrics
      prepare_environment
    end

    def run
      logger.tagged(component: "smtp-server") do
        listen
        run_event_loop
      end
    end

    private

    def prepare_environment
      $\ = "\r\n"
      BasicSocket.do_not_reverse_lookup = true

      trap("TERM") do
        $stdout.puts "Received TERM signal, shutting down."
        unlisten
      end

      trap("INT") do
        $stdout.puts "Received INT signal, shutting down."
        unlisten
      end
    end

    def ssl_context
      @ssl_context ||= begin
        ssl_context      = OpenSSL::SSL::SSLContext.new
        ssl_context.cert = self.class.tls_certificates[0]
        ssl_context.extra_chain_cert = self.class.tls_certificates[1..]
        ssl_context.key = self.class.tls_private_key
        warn_about_legacy_ssl_version_configuration
        Postal::TLS.apply_version_limits(ssl_context,
                                         min: Postal::Config.smtp_server.min_version,
                                         max: Postal::Config.smtp_server.max_version)
        ssl_context.ciphersuites = Postal::Config.smtp_server.ciphersuites if Postal::Config.smtp_server.ciphersuites
        ssl_context.ciphers = Postal::Config.smtp_server.tls_ciphers if Postal::Config.smtp_server.tls_ciphers
        ssl_context
      end
    end

    #
    # `smtp_server.ssl_version` was assigned to an attribute which no longer
    # exists on an OpenSSL context, so setting it has never had any effect. Say
    # so rather than keep ignoring it, but only when it has been changed from
    # the value the default configuration ships with.
    #
    def warn_about_legacy_ssl_version_configuration
      return if @legacy_ssl_version_warned

      configured = Postal::Config.smtp_server.ssl_version.to_s
      return if configured.empty? || configured == "SSLv23"

      @legacy_ssl_version_warned = true
      logger.warn "smtp_server.ssl_version is no longer used. " \
                  "Set smtp_server.min_version and smtp_server.max_version instead."
    end

    def listen
      bind_address = ENV.fetch("BIND_ADDRESS", Postal::Config.smtp_server.default_bind_address)
      port = ENV.fetch("PORT", Postal::Config.smtp_server.default_port)

      @server = TCPServer.open(bind_address, port)
      @server.autoclose = false
      @server.close_on_exec = false
      if defined?(Socket::SOL_SOCKET) && defined?(Socket::SO_KEEPALIVE)
        @server.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)
      end
      if defined?(Socket::SOL_TCP) && defined?(Socket::TCP_KEEPIDLE) && defined?(Socket::TCP_KEEPINTVL) && defined?(Socket::TCP_KEEPCNT)
        @server.setsockopt(Socket::SOL_TCP, Socket::TCP_KEEPIDLE, 50)
        @server.setsockopt(Socket::SOL_TCP, Socket::TCP_KEEPINTVL, 10)
        @server.setsockopt(Socket::SOL_TCP, Socket::TCP_KEEPCNT, 5)
      end

      logger.info "Listening on #{bind_address}:#{port}"
    end

    def unlisten
      # Instruct the nio loop to unlisten and wake it
      @unlisten = true
      @io_selector.wakeup
    end

    def run_event_loop
      # Set up an instance of nio4r to monitor for connections and data
      @io_selector = NIO::Selector.new
      # Register the SMTP listener
      @io_selector.register(@server, :r)
      # Create a hash to contain a buffer for each client.
      buffers = Hash.new { |h, k| h[k] = String.new.force_encoding("BINARY") }
      loop do
        # Wait for an event to occur, waking periodically so idle sessions can
        # be reaped even when no socket is readable.
        @io_selector.select(IDLE_CHECK_INTERVAL) do |monitor|
          # Get the IO from the nio monitor
          io = monitor.io
          # Is this event an incoming connection?
          if io.is_a?(TCPServer)
            begin
              # Accept the connection
              new_io = io.accept
              increment_counter :postal_smtp_server_connections_total
              # Get the client's IP address and strip `::ffff:` for consistency.
              client_ip_address = new_io.remote_address.ip_address.sub(/\A::ffff:/, "")

              # Refuse the connection without serving it if this address is
              # connecting too often or the server is already at its limit.
              next if refuse_connection(new_io, client_ip_address)

              if Postal::Config.smtp_server.proxy_protocol?
                # If we are using the haproxy proxy protocol, we will be sent the
                # client's IP later. Delay the welcome process.
                client = Client.new(nil)
                if Postal::Config.smtp_server.log_connections?
                  client.logger&.debug "Connection opened from #{client_ip_address}"
                end
              else
                # We're not using the proxy protocol so we already know the client's IP
                client = Client.new(client_ip_address)
                if Postal::Config.smtp_server.log_connections?
                  client.logger&.debug "Connection opened from #{client_ip_address}"
                end
                # We know who the client is, welcome them.
                client.logger&.debug "Client identified as #{client_ip_address}"
                new_io.print(Client.reply(220, "2.0.0",
                                          "#{Postal::Config.postal.smtp_hostname} ESMTP Postal/#{client.trace_id}"))
              end
              # Register the client and its socket with nio4r
              monitor = @io_selector.register(new_io, :r)
              monitor.value = client
            rescue StandardError => e
              # If something goes wrong, log as appropriate and disconnect the client
              if defined?(Sentry)
                Sentry.capture_exception(e, extra: { trace_id: begin
                  client.trace_id
                rescue StandardError
                  nil
                end })
              end
              logger.error "An error occurred while accepting a new client."
              logger.error "#{e.class}: #{e.message}"
              e.backtrace.each do |line|
                logger.error line
              end
              increment_counter :postal_smtp_server_exceptions_total,
                                           labels: { error: e.class.to_s, type: "client-accept" }
              begin
                new_io.close
              rescue StandardError
                nil
              end
            end
          else
            # This event is not an incoming connection so it must be data from a client
            begin
              # Get the client from the nio monitor
              client = monitor.value
              # For now we assume the connection isn't closed
              eof = false
              # Is the client negotiating a TLS handshake?
              if client.start_tls?
                begin
                  # Can we accept the TLS connection at this time?
                  io.accept_nonblock
                  # Increment the metric
                  increment_counter :postal_smtp_server_tls_connections_total
                  # We were able to accept the connection, the client is no longer handshaking
                  client.start_tls = false
                rescue IO::WaitReadable, IO::WaitWritable => e
                  # Could not accept without blocking
                  # We will try again later
                  next
                rescue OpenSSL::SSL::SSLError => e
                  client.logger&.debug "SSL Negotiation Failed: #{e.message}"
                  eof = true
                end
              else
                # The client is not negotiating a TLS handshake at this time
                begin
                  # Read 10kiB of data at a time from the socket.
                  buffers[io] << io.readpartial(10_240)

                  # There is an extra step for SSL sockets
                  if io.is_a?(OpenSSL::SSL::SSLSocket)
                    buffers[io] << io.readpartial(10_240) while io.pending.positive?
                  end

                  # A client which never sends a newline would otherwise grow
                  # the buffer without bound; the per-command limit is enforced
                  # once a line arrives, so this only guards the wait for one.
                  if buffers[io].bytesize > SMTPServer::Client::MAX_COMMAND_LINE_LENGTH * 4 && !buffers[io].index("\n")
                    client.logger&.warn "Closing connection with an overlong line"
                    eof = true
                  end
                rescue EOFError, Errno::ECONNRESET, Errno::ETIMEDOUT
                  # Client went away
                  eof = true
                end

                # We line buffer, so look to see if we have received a newline
                # and keep doing so until all buffered lines have been processed.
                # A client which pipelines will have sent several commands in one
                # read, so every buffered line is handled here, in order, and each
                # reply is flushed as it is produced. That is what lets us
                # advertise PIPELINING: the batch is answered as a group rather
                # than one command per turn around the selector.
                while buffers[io].index("\n")
                  # Extract the line
                  line, buffers[io] = buffers[io].split("\n", 2)
                  # Send the received line to the client object for processing
                  result = client.handle(line)
                  # If the client object returned some data, write it back to the client
                  next if result.nil?

                  result = [result] unless result.is_a?(Array)
                  result.compact.each do |iline|
                    client.logger&.debug "\e[34m=> #{iline.strip}\e[0m"
                    begin
                      io.write(iline.to_s + "\r\n")
                      io.flush
                    rescue Errno::ECONNRESET
                      # Client disconnected before we could write response
                      eof = true
                    end
                  end
                end

                # Did the client request STARTTLS?
                if !eof && client.start_tls?
                  # Deregister the unencrypted IO
                  @io_selector.deregister(io)
                  buffers.delete(io)
                  io = OpenSSL::SSL::SSLSocket.new(io, ssl_context)
                  # Close the underlying IO when the TLS socket is closed
                  io.sync_close = true
                  # Register the new TLS socket with nio
                  monitor = @io_selector.register(io, :r)
                  monitor.value = client
                end
              end

              # Has the client requested we close the connection?
              if client.finished? || eof
                client.logger&.debug "Connection closed"
                # Deregister the socket and close it
                @io_selector.deregister(io)
                buffers.delete(io)
                io.close
                # If we have no more clients or listeners left, exit the process
                if @io_selector.empty?
                  Process.exit(0)
                end
              end
            rescue StandardError => e
              # Something went wrong, log as appropriate
              client_id = client ? client.trace_id : "------"
              if defined?(Sentry)
                Sentry.capture_exception(e, extra: { trace_id: begin
                  client&.trace_id
                rescue StandardError
                  nil
                end })
              end
              logger.error "An error occurred while processing data from a client.", trace_id: client_id
              logger.error "#{e.class}: #{e.message}", trace_id: client_id
              e.backtrace.each do |iline|
                logger.error iline, trace_id: client_id
              end

              increment_counter :postal_smtp_server_exceptions_total,
                                           labels: { error: e.class.to_s, type: "data" }

              # Close all IO and forget this client
              begin
                @io_selector.deregister(io)
              rescue StandardError
                nil
              end
              buffers.delete(io)
              begin
                io.close
              rescue StandardError
                nil
              end
              if @io_selector.empty?
                Process.exit(0)
              end
            end
          end
        end
        # Close any session which has been quiet for too long.
        close_idle_connections(buffers)

        # If unlisten has been called, stop listening
        next unless @unlisten

        @io_selector.deregister(@server)
        @server.close
        # If there's nothing left to do, shut down the process
        if @io_selector.empty?
          Process.exit(0)
        end
        # Clear the request
        @unlisten = false
      end
    end

    #
    # Close connections which have not sent anything for longer than the
    # configured idle timeout. A client which opens a connection and then falls
    # silent would otherwise hold its buffers and its slot indefinitely.
    #
    def close_idle_connections(buffers)
      now = Time.now.to_i
      expired = @io_selector.monitors.select do |monitor|
        monitor.value.is_a?(Client) && monitor.value.expired?(now)
      end

      expired.each do |monitor|
        io = monitor.io
        monitor.value.logger&.debug "Closing connection after #{Postal::Config.smtp_server.idle_timeout}s of inactivity"
        increment_counter :postal_smtp_server_idle_timeouts_total
        begin
          io.write(Client.reply(421, "4.4.2", "Idle timeout, closing connection") + "\r\n")
          io.flush
        rescue StandardError
          nil
        end
        begin
          @io_selector.deregister(io)
        rescue StandardError
          nil
        end
        buffers.delete(io)
        begin
          io.close
        rescue StandardError
          nil
        end
      end
    end

    #
    # Answer and close a connection we are not willing to serve, either because
    # the caller is connecting more often than its allowance permits or because
    # the server is already at its concurrent connection limit.
    #
    # @return [Boolean] true when the connection has been refused and closed
    #
    def refuse_connection(io, ip_address)
      reason = connection_refusal_reason(ip_address)
      return false if reason.nil?

      increment_counter :postal_smtp_server_connections_refused_total
      logger.warn "Refusing SMTP connection from #{ip_address} (#{reason})"
      begin
        io.write(Client.reply(421, "4.7.0", "Too many connections, please try again later") + "\r\n")
        io.flush
      rescue StandardError
        nil
      end
      begin
        io.close
      rescue StandardError
        nil
      end
      true
    end

    #
    # Why this connection should be refused, or nil when it should be served.
    #
    def connection_refusal_reason(ip_address)
      max_connections = Postal::Config.protection.smtp_max_connections.to_i
      if max_connections.positive? && @io_selector.monitors.count { |m| m.value.is_a?(Client) } >= max_connections
        return "connection limit reached"
      end

      if Postal::RateLimiter.exceeded?("smtp-connection:#{ip_address}",
                                       limit: Postal::Config.protection.smtp_connections_limit,
                                       period: Postal::Config.protection.smtp_connections_period)
        return "too many connections from this address"
      end

      nil
    end

    def logger
      Postal.logger
    end

    def register_metrics
      register_counter :postal_smtp_server_connections_total,
                                  docstring: "The number of connections made to the Postal SMTP server."

      register_counter :postal_smtp_server_exceptions_total,
                                  docstring: "The number of server exceptions encountered by the SMTP server",
                                  labels: [:type, :error]

      register_counter :postal_smtp_server_tls_connections_total,
                                  docstring: "The number of successfuly TLS connections established"

      register_counter :postal_smtp_server_idle_timeouts_total,
                                  docstring: "The number of connections closed because the client went quiet"

      register_counter :postal_smtp_server_connections_refused_total,
                                  docstring: "The number of connections refused before they were served"

      Client.register_metrics
    end

  end
end
