# frozen_string_literal: true

module Postal
  module MessageDB
    module Migrations
      class AddIndexToMessageStatus < Postal::MessageDB::Migration

        def up
          sql = @database.dialect.add_index_sql(@database.database_name, :messages, :on_status, "`status`(8)")
          @database.query(sql)
        end

      end
    end
  end
end
