# frozen_string_literal: true

module Postal
  module MessageDB
    module Dialects
      #
      # Resolves the dialect for a configured adapter.
      #
      # This registry answers the message store's question only: it resolves the
      # dialect a configured `message_db.adapter` selects, so every entry is a SQL
      # engine. Engines which are not relational are not dialects and are not
      # listed here however they are used — FoundationDB, for instance, backs the
      # blob store.
      #
      class Registry

        class UnsupportedAdapter < Postal::Error
        end

        # The adapter names which can be selected through message_db.adapter.
        ADAPTERS = %w[mariadb mysql postgresql sqlite].freeze

        class << self

          #
          # Return a dialect instance for the given adapter name. Raises
          # UnsupportedAdapter if the engine is unknown or not yet available.
          #
          def for(name)
            dialect = dialect_class(name)&.new
            if dialect.nil? || !dialect.available?
              raise UnsupportedAdapter, "The message database adapter '#{name}' is not supported. " \
                                        "Available adapters are: #{ADAPTERS.join(', ')}."
            end

            dialect
          end

          #
          # The adapter names which can be selected.
          #
          def names
            ADAPTERS
          end

          private

          #
          # Resolve the dialect class for an adapter name. Kept in a method so
          # the constant is looked up at call time and can be autoloaded.
          #
          def dialect_class(name)
            case name.to_s.downcase
            when "mysql", "mariadb" then MySQL
            when "postgres", "postgresql" then PostgreSQL
            when "sqlite" then SQLite
            end
          end

        end

      end
    end
  end
end
