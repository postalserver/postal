# frozen_string_literal: true

module Postal
  module MessageDB
    module Migrations
      #
      # Add the `blob` column to raw message tables. When a blob store is
      # configured, the body of a large message is written to it and only the
      # key is kept in this column (with `data` left NULL) rather than storing
      # the body inline in the database.
      #
      class AddBlobToRaw < Postal::MessageDB::Migration

        def up
          @database.provisioner.raw_tables(nil).each do |table|
            sql = @database.dialect.add_column_sql(@database.database_name, table, :blob, "varchar(64) DEFAULT NULL")
            @database.query(sql)
          end
        end

      end
    end
  end
end
