require 'socket'
require 'openssl'

module Postal
  module FastServer
    class Server

      def run
        if Postal.config.fast_server.bind_address.blank?
          Postal.logger_for(:fast_server).info "Cannot start fast server because no bind address has been specified"
          exit 1
        end

        Thread.abort_on_exception = true
        TrackCertificate

        bind_addresses = Postal.config.fast_server.bind_address
        bind_addresses = [bind_addresses] unless bind_addresses.is_a?(Array)

        server_sockets = bind_addresses.each_with_object({}) do |bind_addr, sockets|
          sockets[TCPServer.new(bind_addr, Postal.config.fast_server.port)] = {:ssl => false}
          sockets[TCPServer.new(bind_addr, Postal.config.fast_server.ssl_port)] = {:ssl => true}
          Postal.logger_for(:fast_server).info("Fast server started listening on HTTP (#{bind_addr}:#{Postal.config.fast_server.port})")
          Postal.logger_for(:fast_server).info("Fast server started listening on HTTPS port (#{bind_addr}:#{Postal.config.fast_server.ssl_port})")
        end

        loop do
          client = nil
          ios = select(server_sockets.keys, nil, nil, 1)
          if ios && server_io = ios[0][0]
            begin
              client_io = server_io.accept_nonblock
              client = Client.new(client_io, server_sockets[server_io])
              Thread.new(client) { |t_client| t_client.run }
            rescue IO::WaitReadable, Errno::EINTR
              # Never mind, guess the client went away
            rescue => e
              if defined?(Raven)
                Raven.capture_exception(e)
              end
              client_io.close rescue nil
            end
          end
        end
      end

    end
  end
end
