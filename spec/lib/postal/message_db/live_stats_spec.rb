# frozen_string_literal: true

require "rails_helper"
require "securerandom"

describe Postal::MessageDB::LiveStats do
  let(:server) { create(:server) }
  subject(:live_stats) { server.message_db.live_stats }

  def redis_client_available?
    require "redis-client"
    true
  rescue LoadError
    false
  end

  context "when the live stats store is the message database" do
    before do
      allow(Postal::Config.live_stats).to receive(:url).and_return("mysql://")
    end

    it "increments and totals counts" do
      type = "spec#{rand(1_000_000)}"

      live_stats.increment(type)
      live_stats.increment(type)

      expect(live_stats.total(5, types: [type])).to eq 2
    end

    it "raises for an unknown scheme" do
      allow(Postal::Config.live_stats).to receive(:url).and_return("carrier-pigeon://x")

      expect { live_stats.increment("incoming") }.to raise_error(Postal::Error, /Unknown live stats scheme/)
    end
  end

  context "when the optional valkey store is configured" do
    before do
      skip "redis-client is not installed" unless redis_client_available?

      allow(Postal::Config.live_stats).to receive(:url)
        .and_return(ENV.fetch("VALKEY_URL", "valkey://valkey:6379/0"))
    end

    it "increments and totals counts in Valkey" do
      type = "spec#{SecureRandom.hex(6)}"

      3.times { live_stats.increment(type) }

      expect(live_stats.total(5, types: [type])).to eq 3
    end
  end
end
