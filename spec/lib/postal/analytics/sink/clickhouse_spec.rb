# frozen_string_literal: true

require "rails_helper"
require "net/http"
require "uri"

describe Postal::Analytics::Sink::ClickHouse do
  let(:url) { ENV["CLICKHOUSE_URL"].to_s }
  let(:database) { "postal_test" }
  let(:server) { create(:server) }
  let(:rows) do
    [["2024-01-01", 3, 2, 1, 0, 0], ["2024-01-02", 5, 4, 0, 1, 2]]
  end
  subject(:sink) { described_class.new("clickhouse://#{URI.parse(url).host}:#{URI.parse(url).port}/#{database}") }

  before do
    skip "set CLICKHOUSE_URL to run the ClickHouse sink spec" if url.empty?

    # The sink talks to a real ClickHouse server over HTTP, so the suite's
    # WebMock must let those connections through.
    WebMock.allow_net_connect!
    clickhouse("DROP DATABASE IF EXISTS #{database}")
  end

  after do
    unless url.empty?
      clickhouse("DROP DATABASE IF EXISTS #{database}")
      WebMock.disable_net_connect!(allow_localhost: true)
    end
  end

  it "loads the rows and replaces them on each run" do
    sink.write(server.id, server.permalink, rows)
    sink.write(server.id, server.permalink, rows)

    clickhouse("OPTIMIZE TABLE #{database}.stats_daily FINAL")
    expect(clickhouse("SELECT count() FROM #{database}.stats_daily FINAL").to_i).to eq 2
    expect(clickhouse("SELECT sum(incoming) FROM #{database}.stats_daily FINAL").to_i).to eq 8
  end

  it "writes nothing when the server has no statistics" do
    sink.write(server.id, server.permalink, [])

    expect(clickhouse("SELECT count() FROM #{database}.stats_daily FINAL").to_i).to eq 0
  end

  #
  # Run a statement over the ClickHouse HTTP interface and return the body.
  #
  def clickhouse(sql)
    uri = URI.parse(url)
    uri.query = URI.encode_www_form(query: sql)
    response = Net::HTTP.post(uri, "")
    raise "ClickHouse error: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    response.body.strip
  end
end
