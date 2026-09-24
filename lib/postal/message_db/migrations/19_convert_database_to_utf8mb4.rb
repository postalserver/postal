# frozen_string_literal: true

module Postal
  module MessageDB
    module Migrations
      class ConvertDatabaseToUtf8mb4 < Postal::MessageDB::Migration

        def up
          @database.dialect.convert_to_utf8mb4_statements(@database.database_name).each do |statement|
            @database.query(statement)
          end
        end

      end
    end
  end
end
