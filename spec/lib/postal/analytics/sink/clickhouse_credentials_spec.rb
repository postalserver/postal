# frozen_string_literal: true

require "rails_helper"

# The credentials for a ClickHouse server are given in analytics.url. None of this
# talks to a server, so unlike the sink itself it runs without one — which is why
# it is not in the spec that needs a ClickHouse to be reachable.
RSpec.describe Postal::Analytics::Sink::ClickHouse do
  it "decodes percent-encoded credentials from the URL" do
    sink = described_class.new("http://user:p%40ss%3Aword@clickhouse:8123/postal")

    expect(sink.send(:credentials)).to eq ["user", "p@ss:word"]
  end

  it "reports no credentials when the URL carries none" do
    sink = described_class.new("http://clickhouse:8123/postal")

    expect(sink.send(:credentials)).to be_nil
  end
end
