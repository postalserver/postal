# frozen_string_literal: true

require "rails_helper"

describe Postal::MessageDB::ConnectionPool do
  subject(:pool) { described_class.new }

  describe "#use" do
    it "yields a connection" do
      counter = 0
      pool.use do |connection|
        expect(connection).to be_a Mysql2::Client
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
      expect(pool.connections).to match [kind_of(Mysql2::Client)]
    end

    it "does not check in connections when there is a connection error" do
      expect do
        pool.use do
          raise Mysql2::Error, "lost connection to server"
        end
      end.to raise_error Mysql2::Error
      expect(pool.connections).to eq []
    end

    it "retries the block once if there is a connection error" do
      clients_seen = []
      expect do
        pool.use do |client|
          clients_seen << client
          raise Mysql2::Error, "lost connection to server"
        end
      end.to raise_error Mysql2::Error
      expect(clients_seen.uniq.size).to eq 2
    end
  end
end
