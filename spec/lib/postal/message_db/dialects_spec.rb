# frozen_string_literal: true

require "rails_helper"

describe Postal::MessageDB::Dialects::Registry do
  describe ".for" do
    it "returns the MySQL dialect for mysql" do
      expect(described_class.for("mysql")).to be_a Postal::MessageDB::Dialects::MySQL
    end

    it "returns the MySQL dialect for mariadb" do
      expect(described_class.for("mariadb")).to be_a Postal::MessageDB::Dialects::MySQL
    end

    it "returns the PostgreSQL dialect for postgresql" do
      expect(described_class.for("postgresql")).to be_a Postal::MessageDB::Dialects::PostgreSQL
    end

    it "returns the PostgreSQL dialect for postgres" do
      expect(described_class.for("postgres")).to be_a Postal::MessageDB::Dialects::PostgreSQL
    end

    it "raises for an adapter that is not available" do
      expect { described_class.for("oracle") }
        .to raise_error(Postal::MessageDB::Dialects::Registry::UnsupportedAdapter, /not supported/)
    end

    it "returns the SQLite dialect for sqlite" do
      expect(described_class.for("sqlite")).to be_a Postal::MessageDB::Dialects::SQLite
    end

    it "reports the adapter names which can be selected" do
      expect(described_class.names).to eq %w[mariadb mysql postgresql sqlite]
    end
  end
end

describe Postal::MessageDB::Dialects::SQLite do
  subject(:dialect) { described_class.new }

  it "is available" do
    expect(dialect).to be_available
  end

  it "quotes identifiers with double quotes" do
    expect(dialect.quote_identifier(:id)).to eq '"id"'
  end

  it "escapes string literals" do
    expect(dialect.escape(nil, "it's")).to eq "'it''s'"
  end

  describe "#column_definition" do
    {
      "int(11) NOT NULL AUTO_INCREMENT" => "INTEGER PRIMARY KEY AUTOINCREMENT",
      "int(11) DEFAULT NULL" => "INTEGER DEFAULT NULL",
      "tinyint(1) DEFAULT 0" => "INTEGER DEFAULT 0",
      "varchar(255) DEFAULT NULL" => "varchar(255) DEFAULT NULL",
      "decimal(18,6) DEFAULT NULL" => "NUMERIC DEFAULT NULL",
      "longblob DEFAULT NULL" => "BLOB DEFAULT NULL",
      "datetime DEFAULT NULL" => "TEXT DEFAULT NULL"
    }.each do |reference, expected|
      it "translates #{reference.inspect}" do
        expect(dialect.column_definition(reference)).to eq expected
      end
    end
  end

  describe "#create_table_statements" do
    it "uses the autoincrement id as the primary key and adds indexes separately" do
      statements = dialect.create_table_statements("db", "things", {
        columns: { id: "int(11) NOT NULL AUTO_INCREMENT", time: "int(11) DEFAULT NULL" },
        indexes: { on_time: "`time`" }
      })

      expect(statements).to eq [
        'CREATE TABLE "db"."things" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "time" INTEGER DEFAULT NULL)',
        'CREATE INDEX "db"."things_on_time" ON "things" ("time")',
      ]
    end

    it "adds a declared composite primary key" do
      statements = dialect.create_table_statements("db", "live_stats", {
        columns: { type: "varchar(20) NOT NULL", minute: "int(11) NOT NULL" },
        primary_key: "`minute`, `type`(8)"
      })

      expect(statements.first).to eq 'CREATE TABLE "db"."live_stats" ("type" varchar(20) NOT NULL, ' \
                                     '"minute" INTEGER NOT NULL, PRIMARY KEY ("minute", "type"))'
    end
  end

  describe "#returning_clause" do
    it "returns the id for normal tables" do
      expect(dialect.returning_clause("messages")).to eq ' RETURNING "id"'
    end

    it "does not for the migrations table which has no id" do
      expect(dialect.returning_clause("migrations")).to be_nil
    end
  end

  describe "#upsert" do
    it "builds an ON CONFLICT clause" do
      expect(dialect.upsert([:time], [[:outgoing, '"outgoing" + 1']]))
        .to eq 'ON CONFLICT ("time") DO UPDATE SET "outgoing" = "outgoing" + 1'
    end
  end
end

describe Postal::MessageDB::Dialects::MySQL do
  subject(:dialect) { described_class.new }

  it "identifies itself as mysql" do
    expect(dialect.name).to eq "mysql"
  end

  it "is available" do
    expect(dialect).to be_available
  end

  describe "#quote_identifier" do
    it "wraps identifiers in backticks" do
      expect(dialect.quote_identifier("id")).to eq "`id`"
    end

    it "doubles embedded backticks so the value cannot break out of the quoting" do
      expect(dialect.quote_identifier("id`=0 OR SLEEP(5)#")).to eq "`id``=0 OR SLEEP(5)#`"
    end

    it "coerces non-string identifiers" do
      expect(dialect.quote_identifier(:token)).to eq "`token`"
    end
  end

  describe "#escape" do
    it "wraps the driver-escaped value in single quotes" do
      connection = double
      allow(connection).to receive(:escape).with("hello").and_return("hello")
      expect(dialect.escape(connection, "hello")).to eq "'hello'"
    end
  end

  describe "#boolean" do
    it "renders booleans as 1 and 0" do
      expect(dialect.boolean(true)).to eq "1"
      expect(dialect.boolean(false)).to eq "0"
    end
  end

  describe "#create_table_statements" do
    it "builds a single CREATE TABLE statement with inline indexes" do
      statements = dialect.create_table_statements("db", "things", {
        columns: { id: "int(11) NOT NULL AUTO_INCREMENT", name: "varchar(255) DEFAULT NULL" },
        indexes: { on_name: "`name`(8)" },
        unique_indexes: { on_unique_name: "`name`" },
        primary_key: "`id`"
      })

      expect(statements).to eq [
        "CREATE TABLE `db`.`things` (`id` int(11) NOT NULL AUTO_INCREMENT, `name` varchar(255) DEFAULT NULL, " \
        "KEY `on_name` (`name`(8)) USING BTREE, UNIQUE KEY `on_unique_name` (`name`), PRIMARY KEY (`id`)) " \
        "ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;",
      ]
    end
  end

  describe "#upsert" do
    it "builds a duplicate-key update clause" do
      expect(dialect.upsert([], [[:outgoing, "`outgoing` + 1"]]))
        .to eq "ON DUPLICATE KEY UPDATE `outgoing` = `outgoing` + 1"
    end

    it "supports multiple assignments" do
      expect(dialect.upsert([:time], [[:a, "1"], [:b, "2"]]))
        .to eq "ON DUPLICATE KEY UPDATE `a` = 1, `b` = 2"
    end
  end

  describe "#conditional_reset_or_increment" do
    it "builds an IF expression" do
      expect(dialect.conditional_reset_or_increment("live_stats", :timestamp, 100, :count))
        .to eq "if(`timestamp` < 100, 1, `count` + 1)"
    end
  end

  describe "#connect" do
    it "creates a Mysql2 client from the message_db configuration" do
      config = double(host: "db", username: "u", password: "p", port: 3306, encoding: "utf8mb4")
      expect(Mysql2::Client).to receive(:new)
        .with(host: "db", username: "u", password: "p", port: 3306, encoding: "utf8mb4")
      dialect.connect(config)
    end
  end
end

describe Postal::MessageDB::Dialects::PostgreSQL do
  subject(:dialect) { described_class.new }

  it "identifies itself as postgresql" do
    expect(dialect.name).to eq "postgresql"
  end

  it "is available" do
    expect(dialect).to be_available
  end

  describe "#quote_identifier" do
    it "wraps identifiers in double quotes" do
      expect(dialect.quote_identifier("id")).to eq '"id"'
    end

    it "doubles embedded double quotes" do
      expect(dialect.quote_identifier('a"b')).to eq '"a""b"'
    end
  end

  describe "#column_definition" do
    it "translates the reference syntax into PostgreSQL types" do
      expect(dialect.column_definition("int(11) NOT NULL AUTO_INCREMENT")).to eq "serial"
      expect(dialect.column_definition("int(11) DEFAULT NULL")).to eq "integer DEFAULT NULL"
      expect(dialect.column_definition("tinyint(1) DEFAULT 0")).to eq "boolean DEFAULT false"
      expect(dialect.column_definition("tinyint(1) DEFAULT NULL")).to eq "boolean DEFAULT NULL"
      expect(dialect.column_definition("tinyint DEFAULT NULL")).to eq "smallint DEFAULT NULL"
      expect(dialect.column_definition("decimal(18,6) DEFAULT NULL")).to eq "numeric(18,6) DEFAULT NULL"
      expect(dialect.column_definition("longblob DEFAULT NULL")).to eq "bytea DEFAULT NULL"
    end

    it "leaves compatible types untouched" do
      expect(dialect.column_definition("varchar(255) DEFAULT NULL")).to eq "varchar(255) DEFAULT NULL"
      expect(dialect.column_definition("bigint DEFAULT NULL")).to eq "bigint DEFAULT NULL"
      expect(dialect.column_definition("text DEFAULT NULL")).to eq "text DEFAULT NULL"
    end
  end

  describe "#create_table_statements" do
    it "emits the table and its indexes as separate statements" do
      statements = dialect.create_table_statements("db", "things", {
        columns: { id: "int(11) NOT NULL AUTO_INCREMENT", name: "varchar(255) DEFAULT NULL", time: "int(11) DEFAULT NULL" },
        unique_indexes: { on_time: "`time`" }
      })

      expect(statements).to eq [
        'CREATE TABLE "db"."things" ("id" serial, "name" varchar(255) DEFAULT NULL, ' \
        '"time" integer DEFAULT NULL, PRIMARY KEY ("id"))',
        'CREATE UNIQUE INDEX "things_on_time" ON "db"."things" ("time")',
      ]
    end

    it "uses the declared primary key" do
      statements = dialect.create_table_statements("db", "live_stats", {
        columns: { type: "varchar(20) NOT NULL", minute: "int(11) NOT NULL" },
        primary_key: "`minute`, `type`(8)"
      })

      expect(statements.first).to eq 'CREATE TABLE "db"."live_stats" ' \
                                     '("type" varchar(20) NOT NULL, "minute" integer NOT NULL, ' \
                                     'PRIMARY KEY ("minute", "type"))'
    end
  end

  describe "#add_column_sql" do
    it "translates the column type" do
      expect(dialect.add_column_sql("db", "messages", :hold_expiry, "decimal(18,6)"))
        .to eq 'ALTER TABLE "db"."messages" ADD COLUMN "hold_expiry" numeric(18,6)'
    end
  end

  describe "#add_index_sql" do
    it "creates an index and drops the MySQL prefix length" do
      expect(dialect.add_index_sql("db", "messages", :on_status, "`status`(8)"))
        .to eq 'CREATE INDEX "messages_on_status" ON "db"."messages" ("status")'
    end
  end

  describe "#change_column_type_sql" do
    it "alters the column type" do
      expect(dialect.change_column_type_sql("db", "links", :url, "TEXT"))
        .to eq 'ALTER TABLE "db"."links" ALTER COLUMN "url" TYPE TEXT'
    end
  end

  describe "#upsert" do
    it "builds an ON CONFLICT clause" do
      expect(dialect.upsert([:time], [[:outgoing, '"outgoing" + 1']]))
        .to eq 'ON CONFLICT ("time") DO UPDATE SET "outgoing" = "outgoing" + 1'
    end
  end

  describe "#conditional_reset_or_increment" do
    it "builds a CASE expression" do
      expect(dialect.conditional_reset_or_increment("live_stats", :timestamp, 100, :count))
        .to eq 'CASE WHEN "live_stats"."timestamp" < 100 THEN 1 ELSE "live_stats"."count" + 1 END'
    end
  end

  describe "#returning_clause" do
    it "returns the generated id" do
      expect(dialect.returning_clause("messages")).to eq ' RETURNING "id"'
    end
  end
end
