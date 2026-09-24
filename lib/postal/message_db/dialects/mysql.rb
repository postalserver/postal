# frozen_string_literal: true

module Postal
  module MessageDB
    module Dialects
      #
      # The MySQL/MariaDB dialect. This is the reference implementation and the
      # only engine which is currently provisioned and supported end to end.
      #
      class MySQL < Base

        # The tables which exist in a message database and are converted to
        # utf8mb4 by migration 19. Listed here so the conversion can be
        # generated rather than repeated in the migration.
        UTF8MB4_TABLES = %w[clicks deliveries links live_stats loads messages
                            migrations raw_message_sizes spam_checks stats_daily
                            stats_hourly stats_monthly stats_yearly suppressions
                            webhook_requests].freeze

        #
        # Wraps the result of an EXPLAIN so it can be handed to the Rails MySQL
        # pretty printer for logging.
        #
        class ExplainResult

          attr_reader :columns
          attr_reader :rows

          def initialize(result)
            if result.first
              @columns = result.first.keys
              @rows = result.map { |row| row.map(&:last) }
            else
              @columns = []
              @rows = []
            end
          end

        end

        def name
          "mysql"
        end

        def available?
          true
        end

        # Identifiers are wrapped in backticks and any backtick within the
        # identifier is doubled so it cannot break out of the quoting and
        # inject arbitrary SQL.
        def quote_identifier(identifier)
          "`" + identifier.to_s.gsub("`", "``") + "`"
        end

        def escape(connection, value)
          "'" + connection.escape(value) + "'"
        end

        def execute(connection, query)
          connection.query(query, cast_booleans: true)
        end

        def explain?
          true
        end

        def log_explain(connection, query, time, logger)
          id = SecureRandom.alphanumeric(8)
          result = ExplainResult.new(connection.query("EXPLAIN #{query}", cast_booleans: true))
          logger.info "  [#{id}] EXPLAIN #{query}"
          ActiveRecord::ConnectionAdapters::MySQL::ExplainPrettyPrinter.new.pp(result, time).split("\n").each do |line|
            logger.info "  [#{id}] " + line
          end
        end

        def error_class
          Mysql2::Error
        end

        def last_insert_id(connection)
          connection.last_id
        end

        def affected_rows(connection, _result)
          connection.affected_rows
        end

        def upsert(_conflict_columns, assignments)
          "ON DUPLICATE KEY UPDATE " +
            assignments.map { |column, expression| "#{quote_identifier(column)} = #{expression}" }.join(", ")
        end

        def conditional_reset_or_increment(_table, column, threshold, counter, reset_value = 1)
          "if(#{quote_identifier(column)} < #{threshold}, #{reset_value}, #{quote_identifier(counter)} + 1)"
        end

        def connect(config)
          require "mysql2"

          Mysql2::Client.new(
            host: config.host,
            username: config.username,
            password: config.password,
            port: config.port,
            encoding: config.encoding
          )
        end

        #
        # Schema
        #

        def create_table_statements(namespace, table, options)
          [create_table_sql(namespace, table, options)]
        end

        def add_column_sql(namespace, table, column, definition)
          "ALTER TABLE #{qualify(namespace, table)} ADD COLUMN #{quote_identifier(column)} #{definition}"
        end

        def add_index_sql(namespace, table, name, definition, unique: false)
          "ALTER TABLE #{qualify(namespace, table)} ADD #{unique ? 'UNIQUE ' : ''}" \
            "INDEX #{quote_identifier(name)} (#{definition}) USING BTREE"
        end

        def change_column_type_sql(namespace, table, column, definition)
          "ALTER TABLE #{qualify(namespace, table)} MODIFY #{quote_identifier(column)} #{definition}"
        end

        def convert_to_utf8mb4_statements(namespace)
          statements = ["ALTER DATABASE #{quote_identifier(namespace)} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"]
          UTF8MB4_TABLES.each do |table|
            statements << "ALTER TABLE #{qualify(namespace, table)} " \
                          "CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
          end
          statements
        end

        def create_namespace_sql(namespace)
          "CREATE DATABASE #{quote_identifier(namespace)} CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        end

        def drop_namespace_sql(namespace)
          "DROP DATABASE #{quote_identifier(namespace)};"
        end

        def namespace_exists_sql(namespace)
          "SELECT schema_name FROM `information_schema`.`schemata` WHERE schema_name = #{literal(namespace)}"
        end

        def list_tables_sql(namespace, like)
          "SHOW TABLES FROM #{quote_identifier(namespace)} LIKE #{literal(like)}"
        end

        def table_name_from_row(row)
          row.to_a.first.last
        end

        private

        # A string literal, for the values compared against catalog columns. These
        # are not identifiers, so quote_identifier does not apply: SQL escapes a
        # quote inside a literal by doubling it.
        def literal(value)
          "'#{value.to_s.gsub("'", "''")}'"
        end

        def qualify(namespace, table)
          "#{quote_identifier(namespace)}.#{quote_identifier(table)}"
        end

        def create_table_sql(namespace, table, options)
          String.new.tap do |s|
            s << "CREATE TABLE #{qualify(namespace, table)} ("
            s << options[:columns].map do |column_name, column_options|
              "#{quote_identifier(column_name)} #{column_options}"
            end.join(", ")
            if options[:indexes]
              s << ", "
              s << options[:indexes].map do |index_name, index_options|
                "KEY #{quote_identifier(index_name)} (#{index_options}) USING BTREE"
              end.join(", ")
            end
            if options[:unique_indexes]
              s << ", "
              s << options[:unique_indexes].map do |index_name, index_options|
                "UNIQUE KEY #{quote_identifier(index_name)} (#{index_options})"
              end.join(", ")
            end
            if options[:primary_key]
              s << ", PRIMARY KEY (#{options[:primary_key]})"
            else
              s << ", PRIMARY KEY (#{quote_identifier(:id)})"
            end

            s << ") ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;"
          end
        end

      end
    end
  end
end
