# frozen_string_literal: true

require "pg"

module Postal
  module MessageDB
    module Dialects
      #
      # The PostgreSQL dialect.
      #
      # PostgreSQL cannot reference tables in another database from a single
      # connection, so where MySQL uses one database per server, PostgreSQL
      # uses one schema per server inside the configured database. A
      # "namespace" is therefore a schema here, and every statement is fully
      # qualified with it.
      #
      class PostgreSQL < Base

        def name
          "postgresql"
        end

        def available?
          true
        end

        # Identifiers are wrapped in double quotes and any embedded double quote
        # is doubled so it cannot break out of the quoting.
        def quote_identifier(identifier)
          "\"" + identifier.to_s.gsub("\"", "\"\"") + "\""
        end

        def escape(connection, value)
          "'" + connection.escape_string(value) + "'"
        end

        def execute(connection, query)
          connection.exec(query)
        end

        def error_class
          PG::Error
        end

        def last_insert_id(_connection)
          raise NotImplementedError, "PostgreSQL reports generated ids with INSERT ... RETURNING"
        end

        def affected_rows(_connection, result)
          result.cmd_tuples
        end

        def returning_clause(table)
          " RETURNING #{quote_identifier(:id)}"
        end

        def inserted_id(_connection, result)
          row = result.first
          row && row["id"].to_i
        end

        def upsert(conflict_columns, assignments)
          columns = conflict_columns.map { |column| quote_identifier(column) }.join(", ")
          "ON CONFLICT (#{columns}) DO UPDATE SET " +
            assignments.map { |column, expression| "#{quote_identifier(column)} = #{expression}" }.join(", ")
        end

        def column_reference(table, column)
          "#{quote_identifier(table)}.#{quote_identifier(column)}"
        end

        def conditional_reset_or_increment(table, column, threshold, counter, reset_value = 1)
          "CASE WHEN #{column_reference(table, column)} < #{threshold} " \
            "THEN #{reset_value} ELSE #{column_reference(table, counter)} + 1 END"
        end

        def connect(config)
          connection = PG::Connection.new(
            host: config.host,
            port: config.port,
            user: config.username,
            password: config.password,
            dbname: config.database
          )
          # Without a type map the driver returns every column as a string.
          # Map the common types so results match what the rest of the message
          # database expects (integers, booleans, numerics, timestamps).
          connection.type_map_for_results = PG::BasicTypeMapForResults.new(connection)
          connection
        end

        #
        # Schema
        #

        # Translate a definition written in the reference (MySQL) syntax.
        # tinyint(1) becomes a real boolean (the values written are 0/1, which
        # PostgreSQL accepts as boolean literals) so truthiness checks behave as
        # they do under MySQL's cast_booleans. Other tinyints stay integral.
        def column_definition(definition)
          definition.to_s.dup.tap do |d|
            d.sub!(/\Aint\(\d+\) NOT NULL AUTO_INCREMENT\z/, "serial")

            if d.start_with?("tinyint(1)")
              d.sub!(/\Atinyint\(1\)/, "boolean")
              d.gsub!(/\bDEFAULT 0\b/, "DEFAULT false")
              d.gsub!(/\bDEFAULT 1\b/, "DEFAULT true")
            else
              d.gsub!(/\btinyint(?:\(\d+\))?/, "smallint")
            end

            d.gsub!(/\bint\(\d+\)/, "integer")
            d.gsub!(/\bdecimal\(/, "numeric(")
            d.gsub!(/\bdatetime\b/, "timestamp")
            d.gsub!(/\blongblob\b/, "bytea")
          end
        end

        def create_table_statements(namespace, table, options)
          columns = options[:columns].map do |column_name, definition|
            "#{quote_identifier(column_name)} #{column_definition(definition)}"
          end

          primary_key = options[:primary_key] ? index_columns(options[:primary_key]) : ["id"]
          columns << "PRIMARY KEY (#{primary_key.map { |c| quote_identifier(c) }.join(', ')})"

          statements = ["CREATE TABLE #{qualify(namespace, table)} (#{columns.join(', ')})"]

          (options[:indexes] || {}).each do |index_name, definition|
            statements << create_index_sql(namespace, table, index_name, definition, unique: false)
          end
          (options[:unique_indexes] || {}).each do |index_name, definition|
            statements << create_index_sql(namespace, table, index_name, definition, unique: true)
          end

          statements
        end

        def add_column_sql(namespace, table, column, definition)
          "ALTER TABLE #{qualify(namespace, table)} ADD COLUMN #{quote_identifier(column)} #{column_definition(definition)}"
        end

        def add_index_sql(namespace, table, name, definition, unique: false)
          create_index_sql(namespace, table, name, definition, unique: unique)
        end

        def change_column_type_sql(namespace, table, column, definition)
          "ALTER TABLE #{qualify(namespace, table)} ALTER COLUMN #{quote_identifier(column)} TYPE #{column_definition(definition)}"
        end

        def create_namespace_sql(namespace)
          "CREATE SCHEMA #{quote_identifier(namespace)}"
        end

        def drop_namespace_sql(namespace)
          "DROP SCHEMA #{quote_identifier(namespace)} CASCADE"
        end

        def namespace_exists_sql(namespace)
          "SELECT schema_name FROM information_schema.schemata WHERE schema_name = #{literal(namespace)}"
        end

        def list_tables_sql(namespace, like)
          "SELECT table_name FROM information_schema.tables " \
            "WHERE table_schema = #{literal(namespace)} AND table_name LIKE #{literal(like)}"
        end

        def table_name_from_row(row)
          row["table_name"]
        end

        private

        # A string literal, for the values compared against catalog columns.
        # These are not identifiers, so quote_identifier does not apply: SQL
        # escapes a quote inside a literal by doubling it.
        def literal(value)
          "'#{value.to_s.gsub("'", "''")}'"
        end

        def qualify(namespace, table)
          "#{quote_identifier(namespace)}.#{quote_identifier(table)}"
        end

        # Index names share a namespace with tables in PostgreSQL, so they are
        # qualified with the table name to avoid collisions between tables which
        # happen to use the same index name (for example on_message_id).
        def create_index_sql(namespace, table, name, definition, unique:)
          columns = index_columns(definition).map { |column| quote_identifier(column) }.join(", ")
          "CREATE #{unique ? 'UNIQUE ' : ''}INDEX #{quote_identifier("#{table}_#{name}")} " \
            "ON #{qualify(namespace, table)} (#{columns})"
        end

      end
    end
  end
end
