require 'socket'
require 'openssl'

module Postal
  module FastServer
    class Server

      def run
        Thread.abort_on_exception = true
        TrackCertificate
        server_sockets = {
          TCPServer.new(Postal.config.fast_server.bind_address, Postal.config.fast_server.ssl_port) => {:ssl => true},
          TCPServer.new(Postal.config.fast_server.bind_address, Postal.config.fast_server.port)     => {:ssl => false},
        }
        Postal.logger_for(:fast_server).info("Fast server started listening on HTTP  port #{Postal.config.fast_server.port}")
        Postal.logger_for(:fast_server).info("Fast server started listening on HTTPS port #{Postal.config.fast_server.ssl_port}")
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
