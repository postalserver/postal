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

    describe "raw message body storage" do
      # Raw bodies larger than the chunk size are split across multiple rows
      # chained via the `next` column so that no single query exceeds the
      # database's max_allowed_packet limit. The chunk size is stubbed small so
      # the tests don't need to move multi-megabyte strings around.
      let(:date) { Date.new(2000, 1, 1) }
      let(:table) { database.raw_table_name_for_date(date) }

      before do
        allow(Postal::Config.message_db).to receive(:raw_message_chunk_size).and_return(1024)
      end

      after do
        database.provisioner.remove_raw_table(table) if database.provisioner.raw_tables(nil).include?(table)
      end

      # Walk a stored body chain and return the ids in order.
      def chain_ids(database, table, id)
        ids = []
        while id
          row = database.select(table, where: { id: id }, limit: 1, fields: [:id, :next]).first
          break if row.nil?

          ids << row["id"]
          id = row["next"]
        end
        ids
      end

      it "stores a small body in a single row which is not chained" do
        _table, _headers_id, body_id = database.insert_raw_message("Subject: Test\r\n\r\nHello world", date)

        row = database.select(table, where: { id: body_id }, limit: 1).first
        expect(row["next"]).to be_nil
        expect(database.raw_message_body(table, body_id)).to eq "Hello world"
      end

      it "splits a large body across chained rows and reassembles it exactly" do
        body = +""
        body << ("x" * 1024 * 3)
        body << "tail"
        _table, _headers_id, body_id = database.insert_raw_message("Subject: Test\r\n\r\n#{body}", date)

        ids = chain_ids(database, table, body_id)
        expect(ids.size).to eq 4
        expect(database.raw_message_body(table, body_id)).to eq body
      end

      it "round-trips a chunked raw message through a message" do
        body = "a" * 2500
        message = database.new_message
        message.mail_from = "from@example.com"
        message.rcpt_to = "to@example.com"
        message.scope = "outgoing"
        message.raw_message = "Subject: Test\r\n\r\n#{body}"
        message.save

        expect(message.reload.raw_message).to eq "Subject: Test\r\n\r\n#{body}"
      end

      it "replaces an existing chunked body and removes the old rows" do
        _table, _headers_id, body_id = database.insert_raw_message("Subject: Test\r\n\r\n#{'a' * 3000}", date)
        old_ids = chain_ids(database, table, body_id)
        expect(old_ids.size).to be > 1

        new_id = database.replace_raw_message_body(table, body_id, "b" * 1500)

        expect(database.raw_message_body(table, new_id)).to eq("b" * 1500)
        old_ids.each do |old_id|
          expect(database.select(table, where: { id: old_id }, limit: 1).first).to be_nil
        end
      end
    end
  end
end
