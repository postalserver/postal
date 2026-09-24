# frozen_string_literal: true

module Postal
  module MessageDB
    module Migrations
      class AddUrlAndHookToWebhooks < Postal::MessageDB::Migration

        def up
          dialect = @database.dialect
          database = @database.database_name

          @database.query(dialect.add_column_sql(database, :webhook_requests, :url, "varchar(255)"))
          @database.query(dialect.add_column_sql(database, :webhook_requests, :webhook_id, "int(11)"))
          @database.query(dialect.add_index_sql(database, :webhook_requests, :on_webhook_id, "`webhook_id`"))
        end

      end
    end
  end
end
