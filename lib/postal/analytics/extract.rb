# frozen_string_literal: true

module Postal
  module Analytics
    #
    # Gathers a server's daily message statistics and hands them to the
    # configured sink (DuckDB, ClickHouse or a time-series protocol).
    #
    class Extract

      def initialize(server)
        @server = server
      end

      #
      # Write the server's statistics to the sink. Returns where the rows went.
      #
      def write
        Sink.build.write(@server.id, @server.permalink, rows)
      end

      private

      #
      # The daily statistics, oldest first, as [date, *counters] arrays.
      #
      def rows
        @server.message_db.select("stats_daily", order: :time).map do |row|
          date = Time.at(row["time"].to_i).utc.to_date.iso8601
          [date, *Counters::NAMES.map { |counter| row[counter].to_i }]
        end
      end

    end
  end
end
