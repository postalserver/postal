# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Postal
  module Analytics
    module Sink
      #
      # Writes an extract into a ClickHouse server over its HTTP interface.
      # ClickHouse has no cheap row deletes, so the table is a
      # ReplacingMergeTree ordered by (server_id, date): re-running an extract
      # inserts new versions of a server's rows which replace the old ones on
      # merge, so readers query with FINAL. Uses only the standard library.
      #
      class ClickHouse

        TABLE = "stats_daily"

        attr_reader :database

        def initialize(url)
          @url = URI.parse(url.to_s)
          @database = @url.path.to_s.delete_prefix("/")
          @database = "default" if @database.empty?
        end

        def write(server_id, permalink, rows)
          ensure_table
          return table_name if rows.empty?

          body = rows.map { |row| JSON.generate(row_hash(server_id, permalink, row)) }.join("\n")
          request("INSERT INTO #{qualified_table} FORMAT JSONEachRow", body)
          table_name
        end

        private

        def table_name
          "#{database}.#{TABLE}"
        end

        def qualified_table
          "#{quote_identifier(database)}.#{quote_identifier(TABLE)}"
        end

        def row_hash(server_id, permalink, row)
          date, *counters = row
          {
            server_id: server_id.to_i,
            server: permalink.to_s,
            date: date,
            **Counters::NAMES.zip(counters.map(&:to_i)).to_h.transform_keys(&:to_sym)
          }
        end

        def ensure_table
          request("CREATE DATABASE IF NOT EXISTS #{quote_identifier(database)}")
          request("CREATE TABLE IF NOT EXISTS #{qualified_table} (" \
                  "server_id UInt32, server String, date Date, incoming Int64, " \
                  "outgoing Int64, spam Int64, bounces Int64, held Int64) " \
                  "ENGINE = ReplacingMergeTree ORDER BY (server_id, date)")
        end

        def quote_identifier(identifier)
          "`#{identifier.to_s.gsub('`', '``')}`"
        end

        #
        # The credentials given in the URL, decoded. Userinfo is percent-encoded,
        # and a password routinely contains characters which have to be (@ and :),
        # so passing the encoded form through authenticates with the wrong
        # password.
        #
        # @return [Array<String>, nil]
        #
        def credentials
          return nil if @url.userinfo.nil?

          user, password = @url.userinfo.split(":", 2)
          [decoded(user), decoded(password)]
        end

        def decoded(value)
          URI.decode_uri_component(value.to_s)
        end

        #
        # Run a statement over the ClickHouse HTTP interface. The statement is
        # passed as the `query` parameter and, for inserts, the payload as the
        # request body.
        #
        def request(query, body = nil)
          uri = @url.dup
          uri.path = "/"
          uri.query = URI.encode_www_form(query: query)
          uri.user = nil
          uri.password = nil

          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == "https"

          http_request = Net::HTTP::Post.new(uri)
          http_request.body = body.to_s
          if (user, password = credentials)
            http_request.basic_auth(user, password)
          end

          response = http.request(http_request)
          unless response.is_a?(Net::HTTPSuccess)
            raise Postal::Error, "ClickHouse request failed (#{response.code}): #{response.body}"
          end

          response.body
        end

      end
    end
  end
end
