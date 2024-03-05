# frozen_string_literal: true

require "ipaddr"
require "nio"

module SMTPServer
  class Server

    include HasPrometheusMetrics

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
      register_prometheus_metrics
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
        ssl_context.ssl_version = Postal::Config.smtp_server.ssl_version if Postal::Config.smtp_server.ssl_version
        ssl_context.ciphers = Postal::Config.smtp_server.tls_ciphers if Postal::Config.smtp_server.tls_ciphers
        ssl_context
      end
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
        # Wait for an event to occur
        @io_selector.select do |monitor|
          # Get the IO from the nio monitor
          io = monitor.io
          # Is this event an incoming connection?
          if io.is_a?(TCPServer)
            begin
              # Accept the connection
              new_io = io.accept
              increment_prometheus_counter :postal_smtp_server_connections_total
              # Get the client's IP address and strip `::ffff:` for consistency.
              client_ip_address = new_io.remote_address.ip_address.sub(/\A::ffff:/, "")
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
                new_io.print("220 #{Postal::Config.postal.smtp_hostname} ESMTP Postal/#{client.trace_id}")
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
              increment_prometheus_counter :postal_smtp_server_exceptions_total,
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
                  # Increment prometheus
                  increment_prometheus_counter :postal_smtp_server_tls_connections_total
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
                rescue EOFError, Errno::ECONNRESET, Errno::ETIMEDOUT
                  # Client went away
                  eof = true
                end

                # We line buffer, so look to see if we have received a newline
                # and keep doing so until all buffered lines have been processed.
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

              increment_prometheus_counter :postal_smtp_server_exceptions_total,
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

    def logger
      Postal.logger
    end

    def register_prometheus_metrics
      register_prometheus_counter :postal_smtp_server_connections_total,
                                  docstring: "The number of connections made to the Postal SMTP server."

      register_prometheus_counter :postal_smtp_server_exceptions_total,
                                  docstring: "The number of server exceptions encountered by the SMTP server",
                                  labels: [:type, :error]

      register_prometheus_counter :postal_smtp_server_tls_connections_total,
                                  docstring: "The number of successfuly TLS connections established"

      Client.register_prometheus_metrics
    end

  end
end
