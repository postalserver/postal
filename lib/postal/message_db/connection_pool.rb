# frozen_string_literal: true

module Postal
  module MessageDB
    class ConnectionPool

      attr_reader :connections

      def initialize
        @connections = []
        @lock = Mutex.new
      end

      # Matches the errors mysql2 raises when a pooled connection has been
      # dropped by the server (e.g. idle longer than `wait_timeout`). The
      # inactivity variant is important: a connection parked in the pool during
      # a quiet period is silently closed server-side, and the next query on it
      # raises "disconnected by the server because of inactivity".
      DEAD_CONNECTION_PATTERN = /(lost connection|gone away|not connected|disconnected by the server|inactivity)/i

      def use
        retried = false
        do_not_checkin = false
        begin
          connection = checkout

          yield connection
        rescue Mysql2::Error => e
          if e.message =~ DEAD_CONNECTION_PATTERN
            # If the connection has failed for a connectivity reason
            # we won't add it back in to the pool so that it'll reconnect
            # next time.
            do_not_checkin = true

            # If we haven't retried yet, we'll retry the block once more.
            if retried == false
              retried = true
              retry
            end
          end

          raise
        ensure
          checkin(connection) unless do_not_checkin
        end
      end

      private

      def checkout
        connection = @lock.synchronize do
          @connections.pop unless @connections.empty?
        end

        if connection
          # A pooled connection may have been closed by the server while it sat
          # idle (e.g. past `wait_timeout`). Verify it is still alive before
          # handing it out. `ping` returns false for a dead connection rather
          # than raising, so we discard it and fall through to a fresh one.
          return connection if connection_alive?(connection)

          close_connection(connection)
        end

        add_new_connection
        checkout
      end

      def connection_alive?(connection)
        connection.ping
      rescue Mysql2::Error
        false
      end

      def close_connection(connection)
        connection.close
      rescue Mysql2::Error
        nil
      end

      def checkin(connection)
        @lock.synchronize do
          @connections << connection
        end
      end

      def add_new_connection
        @lock.synchronize do
          @connections << establish_connection
        end
      end

      def establish_connection
        Mysql2::Client.new(
          host: Postal::Config.message_db.host,
          username: Postal::Config.message_db.username,
          password: Postal::Config.message_db.password,
          port: Postal::Config.message_db.port,
          encoding: Postal::Config.message_db.encoding
        )
      end

    end
  end
end
