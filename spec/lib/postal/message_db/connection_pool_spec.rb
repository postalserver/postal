# frozen_string_literal: true

require "rails_helper"

describe Postal::MessageDB::ConnectionPool do
  subject(:pool) { described_class.new }

  # The pool is engine agnostic, so the assertions use whatever driver the
  # configured adapter resolves to.
  let(:dialect) { Postal::MessageDB::Dialects::Registry.for(Postal::Config.message_db.adapter) }
  let(:client_class) do
    case dialect.name
    when "mysql" then Mysql2::Client
    when "sqlite"
      require "sqlite3"
      SQLite3::Database
    else
      PG::Connection
    end
  end
  let(:error_class) { dialect.error_class }

  describe "#use" do
    it "yields a connection" do
      counter = 0
      pool.use do |connection|
        expect(connection).to be_a client_class
        counter += 1
      end
      expect(counter).to eq 1
    end

    it "checks in a connection after the block has executed" do
      connection = nil
      pool.use do |c|
        expect(pool.connections).to be_empty
        connection = c
      end
      expect(pool.connections).to eq [connection]
    end

    it "checks in a connection if theres an error in the block" do
      expect do
        pool.use do
          raise StandardError
        end
      end.to raise_error StandardError
      expect(pool.connections).to match [kind_of(client_class)]
    end

    it "does not check in connections when there is a connection error" do
      expect do
        pool.use do
          raise error_class, "lost connection to server"
        end
      end.to raise_error error_class
      expect(pool.connections).to eq []
    end

    it "retries the block once if there is a connection error" do
      clients_seen = []
      expect do
        pool.use do |client|
          clients_seen << client
          raise error_class, "lost connection to server"
        end
      end.to raise_error error_class
      expect(clients_seen.uniq.size).to eq 2
    end
  end
end
