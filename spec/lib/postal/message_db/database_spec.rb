# frozen_string_literal: true

require "rails_helper"

describe Postal::MessageDB::Database do
  context "when provisioned" do
    let(:server) { create(:server) }
    subject(:database) { server.message_db }

    it "should be a message db" do
      expect(database).to be_a Postal::MessageDB::Database
    end

    it "should return the current schema version" do
      expect(database.schema_version).to be_a Integer
    end

    describe "#escape_identifier" do
      it "wraps a plain identifier in backticks" do
        expect(database.send(:escape_identifier, "id")).to eq "`id`"
      end

      it "doubles embedded backticks so the value cannot break out of the quoting" do
        expect(database.send(:escape_identifier, "id`=0 OR SLEEP(5)#"))
          .to eq "`id``=0 OR SLEEP(5)#`"
      end

      it "coerces non-string identifiers to a string" do
        expect(database.send(:escape_identifier, :token)).to eq "`token`"
      end
    end

    describe "#hash_to_sql" do
      it "builds a simple equality condition" do
        expect(database.send(:hash_to_sql, { "id" => 5 })).to eq "`id` = '5'"
      end

      it "builds an IN condition for an array of integers" do
        expect(database.send(:hash_to_sql, { "id" => [1, 2] })).to eq "`id` IN (1, 2)"
      end

      it "builds operator conditions for a hash value" do
        expect(database.send(:hash_to_sql, { "id" => { greater_than: 1 } }))
          .to eq "`id` > '1'"
      end

      # Regression tests for GHSA-x2hq-rfpg-3xr5: a backtick in the condition
      # key must be neutralised so it cannot close the identifier quoting and
      # inject arbitrary SQL.
      it "neutralises a backtick injection in an equality key" do
        sql = database.send(:hash_to_sql, { "id`=0 OR SLEEP(5)#" => "x" })
        expect(sql).to eq "`id``=0 OR SLEEP(5)#` = 'x'"
      end

      it "neutralises a backtick injection in an IN key" do
        sql = database.send(:hash_to_sql, { "id`)#" => %w[a b] })
        expect(sql).to eq "`id``)#` IN ('a', 'b')"
      end

      it "neutralises a backtick injection in an operator key" do
        sql = database.send(:hash_to_sql, { "id`#" => { greater_than: 1 } })
        expect(sql).to eq "`id``#` > '1'"
      end
    end

    describe "#select with a hostile condition key" do
      # End-to-end proof against the live test database: the injected key is
      # treated as a single (non-existent) column identifier, so MySQL rejects
      # the query instead of executing the injected SQL.
      it "does not allow SQL injection via the condition key" do
        expect do
          database.select("messages", where: { "id`=0 OR 1=1#" => "x" }, limit: 1)
        end.to raise_error(Mysql2::Error)
      end
    end
  end
end
