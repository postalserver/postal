# frozen_string_literal: true

module Postal
  module MessageDB
    module Migrations
      class AddEndpointsToMessages < Postal::MessageDB::Migration

        def up
          dialect = @database.dialect
          database = @database.database_name

          @database.query(dialect.add_column_sql(database, :messages, :endpoint_id, "int(11)"))
          @database.query(dialect.add_column_sql(database, :messages, :endpoint_type, "varchar(255)"))
        end

      end
    end
  end
end
