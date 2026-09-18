# frozen_string_literal: true

module Postal
  module MessageDB
    module Migrations
      class AddBounceTypeToMessages < Postal::MessageDB::Migration

        def up
          @database.query("ALTER TABLE `#{@database.database_name}`.`messages` ADD COLUMN `bounce_type` varchar(4) DEFAULT NULL")
        end

      end
    end
  end
end
