# frozen_string_literal: true

require "fileutils"

module Postal
  module MessageDB
    module Dialects
      #
      # The SQLite dialect.
      #
      # SQLite has no databases or schemas, so a server's message data lives in
      # its own file which is ATTACHed to the shared connection as a namespace
      # (see #ensure_namespace). It is intended for single-node installs: SQLite
      # is a single-writer engine, and a connection can attach a limited number
      # of databases.
      #
      # SQLite also has no boolean type, and the sqlite3 gem does not coerce
      # one, so the columns MySQL reports as booleans (via cast_booleans) are
      # normalised back to true/false on read -- otherwise the 0/1 integers it
      # returns would be truthy and invert the checks which use them.
      #
      class SQLite < Base

        # Columns declared tinyint(1) in the reference schema, which MySQL
        # returns as booleans and which the rest of Postal reads as booleans.
        BOOLEAN_COLUMNS = %w[
          held inspected spam threat bounce received_with_ssl sent_with_ssl
        ].freeze

        def name
          "sqlite"
        end

        def available?
          true
        end

        def quote_identifier(identifier)
          "\"" + identifier.to_s.gsub("\"", "\"\"") + "\""
        end

        def escape(_connection, value)
          "'" + value.to_s.gsub("'", "''") + "'"
        end

        def execute(connection, query)
          connection.execute(query).map do |row|
            row.is_a?(Hash) ? normalize_row(row) : row
          end
        end

        def error_class
          SQLite3::Exception
        end

        def affected_rows(connection, _result)
          connection.changes
        end

        def returning_clause(table)
          " RETURNING #{quote_identifier(:id)}" unless table.to_s == "migrations"
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

        def conditional_reset_or_increment(_table, column, threshold, counter, reset_value = 1)
          "CASE WHEN #{quote_identifier(column)} < #{threshold} " \
            "THEN #{reset_value} ELSE #{quote_identifier(counter)} + 1 END"
        end

        def connect(config)
          require "sqlite3"

          directory = config.database.to_s
          if directory.empty?
            raise Postal::Error, "message_db.database must be set to the directory holding the " \
                                 "SQLite message database files"
          end

          FileUtils.mkdir_p(directory)

          connection = SQLite3::Database.new(":memory:")
          connection.results_as_hash = true
          connection.busy_timeout = 5000
          connection
        end

        #
        # Namespaces
        #

        def ensure_namespace(connection, namespace)
          path = path_for(namespace)
          attached = attached_names(connection)

          if File.exist?(path)
            unless attached.include?(namespace)
              connection.execute("ATTACH DATABASE #{literal(path)} AS #{quote_identifier(namespace)}")
            end
          elsif attached.include?(namespace)
            connection.execute("DETACH DATABASE #{quote_identifier(namespace)}")
          end
        end

        def prepare_namespace(_namespace)
          FileUtils.mkdir_p(directory)
        end

        def cleanup_namespace(namespace)
          FileUtils.rm_f(path_for(namespace))
        end

        def create_namespace_sql(namespace)
          "ATTACH DATABASE #{literal(path_for(namespace))} AS #{quote_identifier(namespace)}"
        end

        def drop_namespace_sql(namespace)
          "DETACH DATABASE #{quote_identifier(namespace)}"
        end

        def namespace_exists_sql(namespace)
          "SELECT name FROM pragma_database_list WHERE name = #{literal(namespace)}"
        end

        def list_tables_sql(namespace, like)
          "SELECT name FROM #{qualify(namespace, 'sqlite_master')} " \
            "WHERE type = 'table' AND name LIKE #{literal(like)}"
        end

        def table_name_from_row(row)
          row["name"]
        end

        #
        # Schema
        #

        def column_definition(definition)
          definition.to_s.dup.tap do |d|
            d.sub!(/\Aint\(\d+\) NOT NULL AUTO_INCREMENT\z/, "INTEGER PRIMARY KEY AUTOINCREMENT")
            d.gsub!(/\bint\(\d+\)/, "INTEGER")
            d.gsub!(/\btinyint(?:\(\d+\))?/, "INTEGER")
            d.gsub!(/\bdecimal\(\d+,\d+\)/, "NUMERIC")
            d.gsub!(/\bdatetime\b/, "TEXT")
            d.gsub!(/\blongblob\b/, "BLOB")
          end
        end

        def create_table_statements(namespace, table, options)
          columns = options[:columns].map do |name, definition|
            "#{quote_identifier(name)} #{column_definition(definition)}"
          end

          # The default id column is INTEGER PRIMARY KEY AUTOINCREMENT, which is
          # already the primary key; only a declared (composite) primary key is
          # added separately.
          if options[:primary_key]
            keys = index_columns(options[:primary_key]).map { |c| quote_identifier(c) }.join(", ")
            columns << "PRIMARY KEY (#{keys})"
          end

          statements = ["CREATE TABLE #{qualify(namespace, table)} (#{columns.join(', ')})"]

          (options[:indexes] || {}).each do |name, definition|
            statements << create_index_sql(namespace, table, name, definition, unique: false)
          end
          (options[:unique_indexes] || {}).each do |name, definition|
            statements << create_index_sql(namespace, table, name, definition, unique: true)
          end

          statements
        end

        def add_column_sql(namespace, table, column, definition)
          "ALTER TABLE #{qualify(namespace, table)} ADD COLUMN #{quote_identifier(column)} #{column_definition(definition)}"
        end

        def add_index_sql(namespace, table, name, definition, unique: false)
          create_index_sql(namespace, table, name, definition, unique: unique)
        end

        #
        # SQLite is dynamically typed, so a declared type change is unnecessary.
        #
        def change_column_type_sql(_namespace, _table, _column, _definition)
          "SELECT 1"
        end

        def truncate_sql(qualified_table)
          "DELETE FROM #{qualified_table}"
        end

        private

        def qualify(namespace, table)
          "#{quote_identifier(namespace)}.#{quote_identifier(table)}"
        end

        # SQLite expects the schema on the index name, not on the table in
        # CREATE INDEX, and index names are per database, so they are also
        # qualified with the table name to avoid collisions between tables which
        # use the same index name (for example on_message_id).
        def create_index_sql(namespace, table, name, definition, unique:)
          columns = index_columns(definition).map { |column| quote_identifier(column) }.join(", ")
          "CREATE #{unique ? 'UNIQUE ' : ''}INDEX #{quote_identifier(namespace)}.#{quote_identifier("#{table}_#{name}")} " \
            "ON #{quote_identifier(table)} (#{columns})"
        end

        def attached_names(connection)
          connection.execute("PRAGMA database_list").map { |row| row["name"] }
        end

        def normalize_row(row)
          row.each_with_object({}) do |(key, value), output|
            output[key] = normalize_value(key, value)
          end
        end

        def normalize_value(key, value)
          return value unless BOOLEAN_COLUMNS.include?(key) && value.is_a?(Integer)

          value == 1
        end

        def directory
          Postal::Config.message_db.database.to_s
        end

        def path_for(namespace)
          File.join(directory, "#{namespace}.sqlite3")
        end

        def literal(value)
          "'" + value.to_s.gsub("'", "''") + "'"
        end

      end
    end
  end
end
