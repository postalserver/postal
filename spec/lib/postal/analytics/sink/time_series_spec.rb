# frozen_string_literal: true

require "rails_helper"
require "securerandom"

#
# End-to-end checks that the protocol sinks talk to real backends. They are
# gated on the corresponding URL so they skip in the default suite.
#
# What is asserted here is that the backend *accepts* the payload for each
# protocol; the exact encoding of each format is asserted without a server in
# spec/lib/postal/telemetry/escaping_spec.rb. Asserting the stored values back
# through a MetricsQL query is deliberately left out: VictoriaMetrics only keeps
# a bounded window and silently drops samples outside its retention/lookback, so
# such an assertion would test the backend's retention policy rather than our
# code.
#
describe Postal::Analytics::Sink::TimeSeries do
  let(:vm_url) { ENV["VICTORIAMETRICS_URL"].to_s }
  let(:vector_url) { ENV["VECTOR_URL"].to_s }
  let(:server) { create(:server, permalink: "spec-#{SecureRandom.hex(6)}") }

  let(:yesterday) { Date.today - 1 }
  let(:today) { Date.today }
  let(:rows) { [[yesterday.iso8601, 3, 2, 1, 0, 0], [today.iso8601, 5, 4, 0, 1, 2]] }

  # These sinks talk to real backends over HTTP, so WebMock must let them out.
  before { WebMock.allow_net_connect! }
  after { WebMock.disable_net_connect!(allow_localhost: true) }

  context "with VictoriaMetrics over the Prometheus protocol" do
    before { skip "set VICTORIAMETRICS_URL to run this spec" if vm_url.empty? }

    it "posts the series" do
      expect { described_class.new("prometheus+#{vm_url}").write(server.id, server.permalink, rows) }
        .not_to raise_error
    end
  end

  context "with VictoriaMetrics over the InfluxDB protocol" do
    before { skip "set VICTORIAMETRICS_URL to run this spec" if vm_url.empty? }

    it "posts the points in line protocol" do
      expect { described_class.new("influx+#{vm_url}/postal").write(server.id, server.permalink, rows) }
        .not_to raise_error
    end
  end

  context "with a vector.dev http_server" do
    subject(:sink) { described_class.new("json+#{vector_url}") }

    before { skip "set VECTOR_URL to run this spec" if vector_url.empty? }

    it "accepts the line-delimited JSON samples" do
      expect(sink.write(server.id, server.permalink, rows)).to include("postal_stats_daily")
    end
  end
end
