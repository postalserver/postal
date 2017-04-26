require 'ipaddr'
require 'epoll' if RUBY_PLATFORM.include?('linux')

module Postal
  module SMTPServer
    class Server

      def initialize(options = {})
        @options = options
        @options[:ports] ||= Postal.config.smtp_server.ports
        @options[:debug] ||= false
        prepare_environment
      end

      def prepare_environment
        $\ = "\r\n"
        BasicSocket.do_not_reverse_lookup = true

        trap("USR1") do
          STDOUT.puts "Received USR1 signal, respawning."
          fork do
            if ENV['APP_ROOT']
              Dir.chdir(ENV['APP_ROOT'])
            end
            ENV.delete('BUNDLE_GEMFILE')
            exec("bundle exec --keep-file-descriptors rake postal:smtp_server", :close_others => false)
          end
        end

        trap("TERM") do
          STDOUT.puts "Received TERM signal, shutting down."
          unlisten
        end

      end

      def ssl_context
        @ssl_context ||= begin
          ssl_context      = OpenSSL::SSL::SSLContext.new
          certs            =  Postal.smtp_certificates
          ssl_context.cert = certs.shift
          ssl_context.extra_chain_cert = certs
          ssl_context.key  = Postal.smtp_private_key
          ssl_context.ssl_version = "SSLv23"
          ssl_context
        end
      end

      def listen
        if ENV['SERVER_FD']
          @server = TCPServer.for_fd(ENV['SERVER_FD'].to_i)
        else
          @server = TCPServer.open('::', @options[:ports].first)
        end
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
        ENV['SERVER_FD'] = @server.to_i.to_s
      end

      def unlisten
        if @epoll
          @epoll.del(@server)
          if @epoll.size == 0
            Process.exit(0)
          end
        end
        @server.close
      end

      def kill_parent
        Process.kill('TERM', Process.ppid)
      end

      def run_linux
        if ENV['SERVER_FD']
          listen
          kill_parent
        else
          listen
        end
        @epoll = Epoll.create
        logger.info "Listening"
        @epoll.add(@server, Epoll::IN)
        buffers = Hash.new { |h, k| h[k] = String.new.force_encoding('BINARY') }
        clients = {}
        loop do
          evlist = @epoll.wait
          evlist.each do |ev|
            io = ev.data
            if io.is_a?(TCPServer)
              begin
                new_io = io.accept

                if Postal.config.smtp_server.proxy_protocol
                  client = Client.new(nil)
                  if Postal.config.smtp_server.log_connect
                    logger.debug "[#{client.id}] \e[35m   Connection opened from #{new_io.remote_address.ip_address}\e[0m"
                  end
                else
                  client = Client.new(new_io.remote_address.ip_address)
                  if Postal.config.smtp_server.log_connect
                    logger.debug "[#{client.id}] \e[35m   Connection opened from #{new_io.remote_address.ip_address}\e[0m"
                  end
                  client.log "\e[35m   Client identified as #{new_io.remote_address.ip_address}\e[0m"
                  new_io.print("220 #{Postal.config.dns.smtp_server_hostname} ESMTP Postal/#{client.id}")
                end

                clients[new_io] = client
                @epoll.add(new_io, Epoll::IN|Epoll::PRI|Epoll::HUP)
              rescue => e
                Raven.capture_exception(e, :extra => {:log_id => (client.id rescue nil)})
                logger.error "An error occurred while accepting a new client."
                logger.error "#{e.class}: #{e.message}"
                e.backtrace.each do |line|
                  logger.error line
                end
                new_io.close rescue nil
              end
            else
              begin
                client = clients[io]
                eof = false
                begin
                  case io
                  when OpenSSL::SSL::SSLSocket
                    buffers[io] << io.readpartial(10240)
                    while(io.pending > 0)
                      buffers[io] << io.readpartial(10240)
                    end
                  else
                    buffers[io] << io.readpartial(10240)
                  end
                rescue EOFError, Errno::ECONNRESET
                  # Client went away
                  eof = true
                end
                while buffers[io].index("\n")
                  if buffers[io].index("\r\n")
                    line, buffers[io] = buffers[io].split("\r\n", 2)
                  else
                    line, buffers[io] = buffers[io].split("\n", 2)
                  end
                  result = client.handle(line)
                  unless result.nil?
                    result = [result] unless result.is_a?(Array)
                    result.compact.each do |line|
                      client.log "\e[34m=> #{line.strip}\e[0m"
                      begin
                        io.write(line.to_s + "\r\n")
                        io.flush
                      rescue Errno::ECONNRESET
                        # Client disconnected before we could write response
                        eof = true
                      end
                    end
                  end
                end
                if !eof && client.start_tls?
                  client.start_tls = false
                  @epoll.del(io)
                  clients.delete(io)
                  buffers.delete(io)
                  tcp_io = io
                  io = OpenSSL::SSL::SSLSocket.new(io, ssl_context)
                  @epoll.add(io, Epoll::IN)
                  clients[io] = client
                  io.sync_close = true
                  begin
                    io.accept
                  rescue OpenSSL::SSL::SSLError => e
                    client.log "SSL Negotiation Failed: #{e.message}"
                    eof = true
                  end
                end

                if client.finished? || eof
                  client.log "\e[35m   Connection closed\e[0m"
                  @epoll.del(io)
                  clients.delete(io)
                  buffers.delete(io)
                  io.close
                  if @epoll.size == 0
                    Process.exit(0)
                  end
                end
              rescue => e
                client_id = client ? client.id : '------'
                Raven.capture_exception(e, :extra => {:log_id => (client.id rescue nil)})
                logger.error "[#{client_id}] An error occurred while processing data from a client."
                logger.error "[#{client_id}] #{e.class}: #{e.message}"
                e.backtrace.each do |line|
                  logger.error "[#{client_id}] #{line}"
                end
                # Close all IO and forget this client
                @epoll.del(io) rescue nil
                clients.delete(io)
                buffers.delete(io)
                io.close rescue nil
                if @epoll.size == 0
                  Process.exit(0)
                end
              end
            end
          end
        end
      end

      def run_non_linux
        if ENV['SERVER_FD']
          listen
          kill_parent
        else
          listen
        end
        logger.info "Listening"
        Thread.abort_on_exception = true
        client_threads = []
        loop do
          s = nil
          begin
            until s
              l = select([@server], [@server], [@server], 0.5)
              s = @server.accept if l
            end
          rescue IOError
            STDERR.puts "Server socket was closed."
            break
          end
          client_threads << Thread.new(s) do |io|
            begin
              if Postal.config.smtp_server.proxy_protocol
                client = Client.new(nil)
                if Postal.config.smtp_server.log_connect
                  logger.debug "[#{client.id}] \e[35m   Connection opened from #{io.remote_address.ip_address}\e[0m"
                end
              else
                client = Client.new(io.remote_address.ip_address)
                if Postal.config.smtp_server.log_connect
                  logger.debug "[#{client.id}] \e[35m   Connection opened from #{io.remote_address.ip_address}\e[0m"
                end
                client.log "\e[35m   Client identified as #{io.remote_address.ip_address}\e[0m"
                io.print("220 #{Postal.config.dns.smtp_server_hostname} ESMTP Postal/#{client.id}")
              end

              loop do
                if received_data = io.gets
                  if result = client.handle(received_data.chomp)
                    result = [result] unless result.is_a?(Array)
                    result.compact.each do |line|
                      client.log "\e[34m=> #{line.strip}\e[0m"
                      io.write(line.to_s + "\r\n")
                      io.flush
                    end
                  end
                end
                if client.start_tls?
                  client.start_tls = false
                  tcp_io = io
                  io = OpenSSL::SSL::SSLSocket.new(io, ssl_context)
                  io.sync_close = true
                  begin
                    io.accept
                  rescue OpenSSL::SSL::SSLError => e
                    logger.error "SSL Negotiation Failed: #{e.message}"
                    io.close     rescue nil
                    tcp_io.close rescue nil
                    eof = true
                  end
                end
                if received_data.nil? || client.finished?
                  client.log "\e[35m   Connection closed\e[0m"
                  io.close
                  break
                end
              end
            rescue => e
              Raven.capture_exception(e, :extra => {:log_id => (client.id rescue nil)})
              logger.error "An error occurred while handling a client."
              logger.error "#{e.class}: #{e.message}"
              e.backtrace.each do |line|
                logger.error line
              end
              # Close all IO
              io.close rescue nil
            ensure
              client_threads.delete(Thread.current)
            end
          end
        end
        client_threads.each{ |t| t.join unless t == Thread.current }
      end

      def run
        if ENV['PID_FILE']
          File.open(ENV['PID_FILE'], 'w') { |f| f.write(Process.pid.to_s + "\n") }
        end
        if Postal.config.smtp_server&.evented
          logger.info "Running epoll driven server for Linux host.."
          run_linux
        else
          logger.info "Running thread based compatibility server for non-Linux host."
          run_non_linux
        end
      end

      private

      def logger
        Postal.logger_for(:smtp_server)
      end

    end
  end
end
