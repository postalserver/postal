# frozen_string_literal: true

module Postal
  module MessageDB
    class Provisioner

      def initialize(database)
        @database = database
      end

      #
      # Provisions a new database
      #
      def provision
        drop
        create
        migrate(silent: true)
      end

      #
      # Migrate this database
      #
      def migrate(start_from: @database.schema_version, silent: false)
        Postal::MessageDB::Migration.run(@database, start_from: start_from, silent: silent)
      end

      #
      # Does the namespace for this server already exist?
      #
      def exists?
        !!@database.query(dialect.namespace_exists_sql(@database.database_name)).first
      end

      #
      # Creates an empty namespace for this server
      #
      def create
        dialect.prepare_namespace(@database.database_name)
        @database.query(dialect.create_namespace_sql(@database.database_name))
        true
      rescue dialect.error_class => e
        e.message =~ /already exists/i ? false : raise
      end

      #
      # Drops the namespace for this server and everything in it
      #
      def drop
        @database.query(dialect.drop_namespace_sql(@database.database_name))
        dialect.cleanup_namespace(@database.database_name)
        true
      rescue dialect.error_class => e
        e.message =~ /doesn't exist|does not exist|no such database/i ? false : raise
      end

      #
      # Create a new table
      #
      def create_table(table_name, options)
        dialect.create_table_statements(@database.database_name, table_name, options).each do |statement|
          @database.query(statement)
        end
      end

      #
      # Drop a table
      #
      def drop_table(table_name)
        @database.query("DROP TABLE #{qualify(table_name)}")
      end

      #
      # Clean the database. This really only useful in development & testing
      # environment and can be quite dangerous in production.
      #
      def clean
        %w[clicks deliveries links live_stats loads messages
           raw_message_sizes spam_checks stats_daily stats_hourly
           stats_monthly stats_yearly suppressions webhook_requests].each do |table|
          @database.query(dialect.truncate_sql(qualify(table)))
        end
      end

      #
      # Creates a new empty raw message table for the given date. Returns nothing.
      #
      def create_raw_table(table)
        dialect.create_table_statements(@database.database_name, table, columns: {
          id: "int(11) NOT NULL AUTO_INCREMENT",
          data: "longblob DEFAULT NULL",
          blob: "varchar(64) DEFAULT NULL",
          next: "int(11) DEFAULT NULL"
        }).each do |statement|
          @database.query(statement)
        end
        @database.query("INSERT INTO #{qualify(:raw_message_sizes)} " \
                        "(#{quote(:table_name)}, #{quote(:size)}) VALUES (#{@database.escape(table)}, 0)")
      rescue dialect.error_class => e
        # Don't worry if the table already exists, another thread has already run this code.
        raise unless e.message =~ /already exists/
      end

      #
      # Return a list of raw message tables that are older than the given date
      #
      def raw_tables(max_age = 30)
        earliest_date = max_age ? Time.now.utc.to_date - max_age : nil
        [].tap do |tables|
          @database.query(dialect.list_tables_sql(@database.database_name, "raw-%")).each do |row|
            table_name = dialect.table_name_from_row(row)
            date = raw_table_date(table_name)
            next if date.nil?

            if earliest_date.nil? || date < earliest_date
              tables << table_name
            end
          end
        end.sort
      end

      #
      # The date a raw message table covers, taken from its name. A table which
      # matches the listing pattern but whose suffix is not a date is skipped
      # rather than raised over: retention runs on a schedule, and one unexpected
      # table in the namespace should not stop every other table being tidied.
      #
      def raw_table_date(table_name)
        Date.parse(table_name.to_s.gsub(/\Araw-/, ""))
      rescue Date::Error
        nil
      end

      #
      # Tidy all messages
      #
      def remove_raw_tables_older_than(max_age = 30)
        raw_tables(max_age).each do |table|
          remove_raw_table(table)
        end
      end

      #
      # Remove a raw message table
      #
      def remove_raw_table(table)
        delete_raw_table_blobs(table)
        @database.query("UPDATE #{qualify(:messages)} SET raw_table = NULL, raw_headers_id = NULL, " \
                        "raw_body_id = NULL, size = NULL WHERE raw_table = #{@database.escape(table)}")
        @database.query("DELETE FROM #{qualify(:raw_message_sizes)} WHERE table_name = #{@database.escape(table)}")
        drop_table(table)
      end

      #
      # Remove messages from the messages table that are too old to retain
      #
      def remove_messages(max_age = 60)
        time = (Time.now.utc.to_date - max_age.days).to_time.end_of_day
        return unless newest_message_to_remove = @database.select(:messages, where: { timestamp: { less_than_or_equal_to: time.to_f } }, limit: 1, order: :id, direction: "DESC", fields: [:id]).first

        id = newest_message_to_remove["id"]
        [:clicks, :loads, :deliveries, :spam_checks, :messages].each do |table|
          column = table == :messages ? :id : :message_id
          @database.query("DELETE FROM #{qualify(table)} WHERE #{quote(column)} <= #{id}")
        end
      end

      #
      # Remove raw message tables in order order until size is under the given size (given in MB)
      #
      def remove_raw_tables_until_less_than_size(size)
        tables = raw_tables(nil)
        tables_removed = []
        until @database.total_size <= size
          table = tables.shift
          break if table.nil?

          tables_removed << table
          remove_raw_table(table)
        end
        tables_removed
      end

      private

      def dialect
        @database.dialect
      end

      def quote(identifier)
        dialect.quote_identifier(identifier)
      end

      def qualify(table)
        "#{quote(@database.database_name)}.#{quote(table)}"
      end

      #
      # Remove any blobs referenced by the rows of a raw message table. Called
      # before the table is dropped so that externally stored message bodies are
      # cleaned up alongside the rows which referenced them.
      #
      def delete_raw_table_blobs(table)
        store = @database.blob_store
        return if store.nil?

        sql = "SELECT #{quote(:blob)} FROM #{qualify(table)} WHERE #{quote(:blob)} IS NOT NULL"
        @database.query(sql).each do |row|
          store.delete(row["blob"])
        end
      end

    end
  end
end
