# frozen_string_literal: true

module Postal
  module MessageDB
    module Migrations
      class AddTimeToDeliveries < Postal::MessageDB::Migration

        def up
          sql = @database.dialect.add_column_sql(@database.database_name, :deliveries, :time, "decimal(8,2)")
          @database.query(sql)
        end

      end
    end
  end
end
