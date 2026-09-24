# frozen_string_literal: true

module Postal
  module MessageDB
    class LiveStats

      #
      # Keeps the live statistics in the message database, whatever engine it
      # uses. Named Database rather than after one engine: the SQL goes through
      # the message database's own dialect.
      #
      class Database

        def initialize(database)
          @database = database
        end

        def increment(type)
          time = Time.now.utc
          dialect = @database.dialect
          type = @database.escape(type.to_s)
          assignments = [
            [:count, dialect.conditional_reset_or_increment("live_stats", :timestamp, time.to_f - 1800, :count)],
            [:timestamp, time.to_f],
          ]
          columns = [:type, :minute, :timestamp, :count].map { |c| dialect.quote_identifier(c) }.join(", ")
          sql_query = "INSERT INTO #{live_stats_table(dialect)} (#{columns})"
          sql_query << " VALUES (#{type}, #{time.min}, #{time.to_f}, 1)"
          sql_query << " #{dialect.upsert([:minute, :type], assignments)}"
          @database.query(sql_query)
        end

        def total(minutes, options = {})
          time = minutes.minutes.ago.beginning_of_minute.utc.to_f
          dialect = @database.dialect
          types = options[:types].map { |t| @database.escape(t.to_s) }.join(", ")
          query = "SELECT SUM(count) as count FROM #{live_stats_table(dialect)} " \
                  "WHERE #{dialect.quote_identifier(:type)} IN (#{types}) AND timestamp > #{time}"
          result = @database.query(query).first
          result["count"] || 0
        end

        private

        #
        # The quoted, fully qualified name of the live stats table.
        #
        def live_stats_table(dialect)
          "#{dialect.quote_identifier(@database.database_name)}.#{dialect.quote_identifier('live_stats')}"
        end

      end

    end
  end
end
