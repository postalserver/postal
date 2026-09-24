# frozen_string_literal: true

require "fileutils"
require "uri"

module Postal
  module Analytics
    module Sink
      #
      # Writes an extract into an embedded DuckDB database, where it can be
      # queried with SQL. Requires the optional 'analytics' bundle group.
      #
      class DuckDB

        DATABASE = "postal-analytics.duckdb"

        CREATE_TABLE = "CREATE TABLE IF NOT EXISTS stats_daily (" \
                       "server_id INTEGER, server VARCHAR, date DATE, incoming BIGINT, " \
                       "outgoing BIGINT, spam BIGINT, bounces BIGINT, held BIGINT)"

        #
        # The URL names the directory the database file lives in.
        #
        def initialize(url)
          @url = URI.parse(url.to_s)
        end

        #
        # Write the rows into the DuckDB database named by analytics.url.
        # Returns the path of the database.
        #
        def write(server_id, permalink, rows)
          path = database_path
          FileUtils.mkdir_p(File.dirname(path))

          database = open_database(path)
          begin
            write_to(database.connect, server_id, permalink, rows)
          ensure
            database.close
          end
          path
        end

        #
        # Load the rows into an already-open connection. Kept separate from
        # #write so it can be exercised against an in-memory database without
        # touching the filesystem.
        #
        def write_to(connection, server_id, permalink, rows)
          connection.query(CREATE_TABLE)
          connection.query("BEGIN")
          begin
            connection.query("DELETE FROM stats_daily WHERE server_id = ?", server_id.to_i)
            insert_rows(connection, server_id, permalink, rows)
            connection.query("COMMIT")
          rescue StandardError
            connection.query("ROLLBACK")
            raise
          end

          connection
        end

        private

        #
        # One bound INSERT for the whole extract. The values are passed as
        # parameters rather than interpolated, so nothing here needs escaping.
        #
        def insert_rows(connection, server_id, permalink, rows)
          return if rows.empty?

          # server_id, permalink, date, then one per counter.
          columns = 3 + Postal::Analytics::Counters::NAMES.size
          placeholders = rows.map { "(#{Array.new(columns, '?').join(', ')})" }.join(", ")
          values = rows.flat_map do |date, *counters|
            [server_id.to_i, permalink.to_s, date, *counters.map(&:to_i)]
          end

          connection.query("INSERT INTO stats_daily VALUES #{placeholders}", *values)
        end

        def database_path
          directory = @url.path.to_s
          if directory.empty?
            raise Postal::Error, "analytics.url must name a directory for the DuckDB analytics extract"
          end

          File.join(directory, DATABASE)
        end

        def open_database(path)
          Postal.require_optional_gem("duckdb", group: "analytics")
          DuckDB::Database.open(path)
        end

      end
    end
  end
end
