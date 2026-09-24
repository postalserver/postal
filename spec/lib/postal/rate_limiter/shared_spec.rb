# frozen_string_literal: true

require "rails_helper"
require "securerandom"

#
# Stands in for a redis-client connection so the counting logic is exercised
# wherever the suite runs, with no server required.
#
class FakeRedisConnection

  attr_reader :calls

  def initialize
    @calls = []
    @hits = Hash.new(0)
  end

  def call(command, *arguments)
    @calls << [command, *arguments]

    case command
    when "EVAL"
      key = arguments[2]
      period = arguments[3]
      @hits[key] += 1
      [@hits[key], period]
    when "DEL"
      @hits.delete(arguments.first)
      1
    end
  end

end

describe Postal::RateLimiter::Shared do
  let(:connection) { FakeRedisConnection.new }

  describe "counting" do
    subject(:store) { described_class.new("redis://example.com:6379/0") }

    before { allow(described_class).to receive(:client).and_return(connection) }

    it "counts with one script, so a key cannot be left without a lifetime" do
      store.increment("key", limit: 5, period: 60)

      expect(connection.calls.size).to eq 1
      expect(connection.calls.first.first).to eq "EVAL"
    end

    it "reports the count and what is left of the window" do
      store.increment("key", limit: 5, period: 60)
      result = store.increment("key", limit: 5, period: 60)

      expect(result.hits).to eq 2
      expect(result.retry_after).to eq 60
      expect(result).to be_allowed
    end

    it "exceeds the limit one event past it" do
      6.times { store.increment("key", limit: 5, period: 60) }

      expect(store.increment("key", limit: 5, period: 60)).to be_exceeded
    end

    it "removes the key when it is cleared" do
      store.increment("key", limit: 5, period: 60)

      store.clear("key")

      expect(connection.calls.last).to eq %w[DEL key]
    end
  end

  describe "against a running server" do
    let(:url) { ENV["REDIS_URL"].to_s }

    before { skip "set REDIS_URL to run the shared store against a server" if url.empty? }

    subject(:store) { described_class.new(url) }

    it "counts, refuses and clears through a real connection" do
      key = "spec:#{SecureRandom.hex(8)}"

      expect(store.increment(key, limit: 2, period: 60).hits).to eq 1
      expect(store.increment(key, limit: 2, period: 60).hits).to eq 2
      expect(store.increment(key, limit: 2, period: 60)).to be_exceeded
      expect(store.increment(key, limit: 2, period: 60).retry_after).to be_between(1, 60)

      store.clear(key)

      expect(store.increment(key, limit: 2, period: 60).hits).to eq 1
    end

    it "leaves a lifetime on the key rather than leaving it behind" do
      key = "spec:#{SecureRandom.hex(8)}"

      store.increment(key, limit: 2, period: 60)

      expect(described_class.client(url).call("TTL", key)).to be_between(1, 60)
    end
  end
end
