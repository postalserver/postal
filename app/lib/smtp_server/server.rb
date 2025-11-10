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

    # --- MODIFIED SECTION ---
    def listen
      bind_address = ENV.fetch("BIND_ADDRESS", Postal::Config.smtp_server.default_bind_address)
      port = ENV.fetch("PORT", Postal::Config.smtp_server.default_port)

      @servers = []

      # Si "::" -> IPv6 (et peut-être IPv4 selon bindv6only)
      if bind_address == "::" || bind_address == "0.0.0.0"
        ["::", "0.0.0.0"].uniq.each do |addr|
          begin
            s = TCPServer.new(addr, port)
            s.autoclose = false
            s.close_on_exec = false
            if defined?(Socket::SOL_SOCKET) && defined?(Socket::SO_KEEPALIVE)
              s.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)
            end
            if defined?(Socket::SOL_TCP) && defined?(Socket::TCP_KEEPIDLE) && defined?(Socket::TCP_KEEPINTVL) && defined?(Socket::TCP_KEEPCNT)
              s.setsockopt(Socket::SOL_TCP, Socket::TCP_KEEPIDLE, 50)
              s.setsockopt(Socket::SOL_TCP, Socket::TCP_KEEPINTVL, 10)
              s.setsockopt(Socket::SOL_TCP, Socket::TCP_KEEPCNT, 5)
            end
            @servers << s
            logger.info "Listening on #{addr}:#{port}"
          rescue => e
            logger.warn "Cannot bind to #{addr}:#{port} - #{e.message}"
          end
        end
      else
        # Sinon, comportement original
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
        @servers = [@server]
        logger.info "Listening on #{bind_address}:#{port}"
      end
    end
    # --- END MODIFIED SECTION ---

    def unlisten
      # Instruct the nio loop to unlisten and wake it
      @unlisten = true
      @io_selector.wakeup
    end

    def run_event_loop
      # Set up an instance of nio4r to monitor for connections and data
      @io_selector = NIO::Selector.new

      # Register all listening sockets
      @servers.each { |srv| @io_selector.register(srv, :r) }

      # Create a hash to contain a buffer for each client.
      buffers = Hash.new { |h, k| h[k] = String.new.force_encoding("BINARY") }

      loop do
        @io_selector.select do |monitor|
          io = monitor.io

          # Accept new client connections from any listener
          if @servers.include?(io)
            begin
              new_io = io.accept
              increment_prometheus_counter :postal_smtp_server_connections_total
              client_ip_address = new_io.remote_address.ip_address.sub(/\A::ffff:/, "")
              if Postal::Config.smtp_server.proxy_protocol?
                client = Client.new(nil)
                client.logger&.debug "Connection opened from #{client_ip_address}" if Postal::Config.smtp_server.log_connections?
              else
                client = Client.new(client_ip_address)
                if Postal::Config.smtp_server.log_connections?
                  client.logger&.debug "Connection opened from #{client_ip_address}"
                end
                client.logger&.debug "Client identified as #{client_ip_address}"
                new_io.print("220 #{Postal::Config.postal.smtp_hostname} ESMTP Postal/#{client.trace_id}")
              end
              monitor = @io_selector.register(new_io, :r)
              monitor.value = client
            rescue StandardError => e
              if defined?(Sentry)
                Sentry.capture_exception(e, extra: { trace_id: begin
                  client.trace_id
                rescue StandardError
                  nil
                end })
              end
              logger.error "An error occurred while accepting a new client."
              logger.error "#{e.class}: #{e.message}"
              e.backtrace.each { |line| logger.error line }
              increment_prometheus_counter :postal_smtp_server_exceptions_total,
                                           labels: { error: e.class.to_s, type: "client-accept" }
              begin
                new_io.close
              rescue StandardError
                nil
              end
            end
          else
            # (reste du code original pour gérer les clients)
            begin
              client = monitor.value
              eof = false

              if client.start_tls?
                begin
                  io.accept_nonblock
                  increment_prometheus_counter :postal_smtp_server_tls_connections_total
                  client.start_tls = false
                rescue IO::WaitReadable, IO::WaitWritable
                  next
                rescue OpenSSL::SSL::SSLError => e
                  client.logger&.debug "SSL Negotiation Failed: #{e.message}"
                  eof = true
                end
              else
                begin
                  buffers[io] << io.readpartial(10_240)
                  if io.is_a?(OpenSSL::SSL::SSLSocket)
                    buffers[io] << io.readpartial(10_240) while io.pending.positive?
                  end
                rescue EOFError, Errno::ECONNRESET, Errno::ETIMEDOUT
                  eof = true
                end

                while buffers[io].index("\n")
                  line, buffers[io] = buffers[io].split("\n", 2)
                  result = client.handle(line)
                  next if result.nil?
                  result = [result] unless result.is_a?(Array)
                  result.compact.each do |iline|
                    client.logger&.debug "\e[34m=> #{iline.strip}\e[0m"
                    begin
                      io.write(iline.to_s + "\r\n")
                      io.flush
                    rescue Errno::ECONNRESET
                      eof = true
                    end
                  end
                end

                if !eof && client.start_tls?
                  @io_selector.deregister(io)
                  buffers.delete(io)
                  io = OpenSSL::SSL::SSLSocket.new(io, ssl_context)
                  io.sync_close = true
                  monitor = @io_selector.register(io, :r)
                  monitor.value = client
                end
              end

              if client.finished? || eof
                client.logger&.debug "Connection closed"
                @io_selector.deregister(io)
                buffers.delete(io)
                io.close
                Process.exit(0) if @io_selector.empty?
              end
            rescue StandardError => e
              client_id = client ? client.trace_id : "------"
              if defined?(Sentry)
                Sentry.capture_exception(e, extra: { trace_id: client&.trace_id rescue nil })
              end
              logger.error "An error occurred while processing data from a client.", trace_id: client_id
              logger.error "#{e.class}: #{e.message}", trace_id: client_id
              e.backtrace.each { |iline| logger.error iline, trace_id: client_id }
              increment_prometheus_counter :postal_smtp_server_exceptions_total,
                                           labels: { error: e.class.to_s, type: "data" }
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
              Process.exit(0) if @io_selector.empty?
            end
          end
        end

        next unless @unlisten

        @servers.each { |srv| @io_selector.deregister(srv) rescue nil }
        @servers.each { |srv| srv.close rescue nil }
        Process.exit(0) if @io_selector.empty?
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