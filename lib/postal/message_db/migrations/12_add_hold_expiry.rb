# frozen_string_literal: true

module Postal
  module MessageDB
    module Migrations
      class AddHoldExpiry < Postal::MessageDB::Migration

        def up
          sql = @database.dialect.add_column_sql(@database.database_name, :messages, :hold_expiry, "decimal(18,6)")
          @database.query(sql)
        end

      end
    end
  end
end
