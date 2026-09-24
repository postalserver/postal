# frozen_string_literal: true

require "rails_helper"

describe Postal::Analytics::Extract do
  let(:server) { create(:server) }
  let(:sink) { instance_double(Postal::Analytics::Sink::DuckDB) }
  subject(:extract) { described_class.new(server) }

  before do
    allow(Postal::Analytics::Sink).to receive(:build).and_return(sink)

    message_db = server.message_db
    message_db.insert("stats_daily", time: Time.utc(2024, 1, 1).to_i, incoming: 3, outgoing: 2, spam: 1, bounces: 0, held: 0)
    message_db.insert("stats_daily", time: Time.utc(2024, 1, 2).to_i, incoming: 5, outgoing: 4, spam: 0, bounces: 1, held: 2)
  end

  it "hands the server's daily statistics to the configured sink" do
    expect(sink).to receive(:write).with(
      server.id,
      server.permalink,
      [
        ["2024-01-01", 3, 2, 1, 0, 0],
        ["2024-01-02", 5, 4, 0, 1, 2],
      ]
    )

    extract.write
  end
end
