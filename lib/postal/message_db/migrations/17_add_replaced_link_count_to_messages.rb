# frozen_string_literal: true

module Postal
  module MessageDB
    module Migrations
      class AddReplacedLinkCountToMessages < Postal::MessageDB::Migration

        def up
          dialect = @database.dialect
          database = @database.database_name

          @database.query(dialect.add_column_sql(database, :messages, :tracked_links, "int(11) DEFAULT 0"))
          @database.query(dialect.add_column_sql(database, :messages, :tracked_images, "int(11) DEFAULT 0"))
          @database.query(dialect.add_column_sql(database, :messages, :parsed, "tinyint DEFAULT 0"))
        end

      end
    end
  end
end
