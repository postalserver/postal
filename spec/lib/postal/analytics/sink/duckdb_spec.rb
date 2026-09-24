# frozen_string_literal: true

require "rails_helper"

describe Postal::Analytics::Sink::DuckDB do
  # The URL only names the directory the file database would live in; these
  # examples write to an in-memory database through #write_to.
  subject(:sink) { described_class.new("duckdb:///var/lib/postal/analytics") }

  let(:rows) do
    [["2024-01-01", 3, 2, 1, 0, 0], ["2024-01-02", 5, 4, 0, 1, 2]]
  end

  before do
    skip "the optional analytics group (duckdb) is not installed" unless duckdb_available?
  end

  def duckdb_available?
    require "duckdb"
    true
  rescue LoadError
    false
  end

  #
  # Exercise the sink against an in-memory DuckDB database, so no directory is
  # needed.
  #
  def with_connection
    database = DuckDB::Database.open(":memory:")
    connection = database.connect
    yield connection
  ensure
    connection&.close
    database&.close
  end

  it "loads the rows into DuckDB" do
    with_connection do |connection|
      sink.write_to(connection, 42, "example", rows)

      totals = connection.query("SELECT SUM(incoming), SUM(held) FROM stats_daily WHERE server_id = 42").first
      expect(totals[0].to_i).to eq 8
      expect(totals[1].to_i).to eq 2
    end
  end

  it "replaces a server's rows on each run rather than appending" do
    with_connection do |connection|
      sink.write_to(connection, 42, "example", rows)
      sink.write_to(connection, 42, "example", rows)

      count = connection.query("SELECT COUNT(*) FROM stats_daily WHERE server_id = 42").first
      expect(count[0].to_i).to eq 2
    end
  end

  it "writes nothing when the server has no statistics" do
    with_connection do |connection|
      sink.write_to(connection, 42, "example", [])

      count = connection.query("SELECT COUNT(*) FROM stats_daily").first
      expect(count[0].to_i).to eq 0
    end
  end
end
