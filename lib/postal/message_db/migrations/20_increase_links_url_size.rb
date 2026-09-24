# frozen_string_literal: true

module Postal
  module MessageDB
    module Migrations
      class IncreaseLinksUrlSize < Postal::MessageDB::Migration

        def up
          sql = @database.dialect.change_column_type_sql(@database.database_name, :links, :url, "TEXT")
          @database.query(sql)
        end

      end
    end
  end
end
