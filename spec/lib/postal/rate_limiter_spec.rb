# frozen_string_literal: true

require "rails_helper"

module Postal

  describe RateLimiter do
    before do
      described_class.store = described_class::Memory.new
    end

    after do
      described_class.reset!
    end

    describe ".check" do
      it "allows events up to the limit and refuses the one after" do
        3.times do |index|
          result = described_class.check("key", limit: 3, period: 60)
          expect(result).to be_allowed
          expect(result.remaining).to eq 2 - index
        end

        result = described_class.check("key", limit: 3, period: 60)
        expect(result).to be_exceeded
        expect(result.remaining).to eq 0
      end

      it "reports how long the caller should wait before retrying" do
        result = described_class.check("key", limit: 1, period: 60)

        expect(result.retry_after).to be_between(1, 60)
      end

      it "counts each key separately" do
        2.times { described_class.check("first", limit: 1, period: 60) }

        expect(described_class.check("second", limit: 1, period: 60)).to be_allowed
      end

      it "namespaces keys with the configured prefix" do
        expect(described_class.store).to receive(:increment)
          .with("postal:limits:thing", limit: 1, period: 60)
          .and_return(described_class::Result.new(1, 1, 0))

        described_class.check("thing", limit: 1, period: 60)
      end

      it "starts a fresh count when the period has elapsed" do
        described_class.check("key", limit: 1, period: 60)
        expect(described_class.check("key", limit: 1, period: 60)).to be_exceeded

        travel_to(Time.now + 61) do
          expect(described_class.check("key", limit: 1, period: 60)).to be_allowed
        end
      end

      it "refuses a limit which is not positive" do
        expect { described_class.check("key", limit: 0, period: 60) }
          .to raise_error(described_class::Error)
      end

      it "refuses a period which is not positive" do
        expect { described_class.check("key", limit: 1, period: 0) }
          .to raise_error(described_class::Error)
      end
    end

    describe ".exceeded?" do
      it "answers false while inside the limit and true once past it" do
        expect(described_class.exceeded?("key", limit: 1, period: 60)).to be false
        expect(described_class.exceeded?("key", limit: 1, period: 60)).to be true
      end
    end

    describe "when the limiter is switched off" do
      before do
        allow(Postal::Config.protection).to receive(:enabled).and_return(false)
      end

      it "allows everything and counts nothing" do
        expect(described_class.store).not_to receive(:increment)

        10.times do
          expect(described_class.check("key", limit: 1, period: 60)).to be_allowed
        end
      end
    end

    describe "the memory store" do
      subject(:store) { described_class::Memory.new }

      it "counts within a window and resets at the boundary" do
        expect(store.increment("key", limit: 2, period: 60).hits).to eq 1
        expect(store.increment("key", limit: 2, period: 60).hits).to eq 2

        travel_to(Time.now + 61) do
          expect(store.increment("key", limit: 2, period: 60).hits).to eq 1
        end
      end

      it "is safe to use from several threads at once" do
        threads = Array.new(10) do
          Thread.new { 100.times { store.increment("key", limit: 1000, period: 60) } }
        end
        threads.each(&:join)

        expect(store.increment("key", limit: 1000, period: 60).hits).to eq 1001
      end

      it "keeps counting correctly once it has had to sweep expired keys" do
        stub_const("Postal::RateLimiter::Memory::PRUNE_THRESHOLD", 1)
        store = described_class::Memory.new

        # Crossing the threshold runs the sweep, which must not disturb counting.
        expect(store.increment("a", limit: 1, period: 60).hits).to eq 1
        expect(store.increment("b", limit: 1, period: 60).hits).to eq 1
        expect(store.increment("a", limit: 1, period: 60).hits).to eq 2

        travel_to(Time.now + 61) do
          expect(store.increment("a", limit: 1, period: 60).hits).to eq 1
        end
      end

      it "clears a single key without touching the others" do
        store.increment("a", limit: 5, period: 60)
        store.increment("b", limit: 5, period: 60)

        store.clear("a")

        expect(store.increment("a", limit: 5, period: 60).hits).to eq 1
        expect(store.increment("b", limit: 5, period: 60).hits).to eq 2
      end

      it "accepts a clear for a key it has never seen" do
        expect { store.clear("never-seen") }.not_to raise_error
      end
    end

    describe "limits which cannot be honoured" do
      it "refuses a negative limit" do
        expect { described_class.check("key", limit: -1, period: 60) }
          .to raise_error(described_class::Error)
      end

      it "refuses a negative period" do
        expect { described_class.check("key", limit: 1, period: -60) }
          .to raise_error(described_class::Error)
      end

      it "refuses a limit which is not a number" do
        expect { described_class.check("key", limit: "many", period: 60) }
          .to raise_error(described_class::Error)
      end
    end

    describe ".clear" do
      it "restores the full allowance" do
        described_class.check("key", limit: 1, period: 60)
        expect(described_class.check("key", limit: 1, period: 60)).to be_exceeded

        described_class.clear("key")

        expect(described_class.check("key", limit: 1, period: 60)).to be_allowed
      end

      it "is harmless for a key which was never counted" do
        expect { described_class.clear("never-seen") }.not_to raise_error
      end

      it "does no work when the limiter is switched off" do
        allow(Postal::Config.protection).to receive(:enabled).and_return(false)

        expect(described_class.store).not_to receive(:clear)
        described_class.clear("key")
      end
    end

    describe "the result" do
      it "treats the limit itself as allowed" do
        result = described_class::Result.new(5, 5, 30)

        expect(result).to be_allowed
        expect(result.remaining).to eq 0
      end

      it "treats one past the limit as exceeded" do
        expect(described_class::Result.new(6, 5, 30)).to be_exceeded
      end

      it "never reports a negative remaining count" do
        expect(described_class::Result.new(50, 5, 30).remaining).to eq 0
      end

      it "allows everything when it is unlimited" do
        expect(described_class::UNLIMITED).to be_allowed
        expect(described_class::UNLIMITED.remaining).to eq Float::INFINITY
      end
    end

    describe "namespacing" do
      it "leaves the key alone when no prefix is configured" do
        allow(Postal::Config.protection).to receive(:prefix).and_return("")
        expect(described_class.store).to receive(:increment)
          .with("thing", limit: 1, period: 60)
          .and_return(described_class::Result.new(1, 1, 0))

        described_class.check("thing", limit: 1, period: 60)
      end
    end

    describe "choosing a store" do
      it "builds the in-process store for the default URL" do
        described_class.reset!

        expect(described_class.store).to be_a(described_class::Memory)
      end

      it "builds the shared store for a redis URL" do
        allow(Postal::Config.protection).to receive(:counter_store).and_return("redis://example.com:6379/0")
        described_class.reset!

        expect(described_class.store).to be_a(described_class::Shared)
      end

      it "accepts valkey as another name for the shared store" do
        allow(Postal::Config.protection).to receive(:counter_store).and_return("valkey://example.com:6379/0")
        described_class.reset!

        expect(described_class.store).to be_a(described_class::Shared)
      end

      it "refuses a scheme it cannot honour rather than quietly counting locally" do
        allow(Postal::Config.protection).to receive(:counter_store).and_return("memcached://example.com:11211")
        described_class.reset!

        expect { described_class.store }
          .to raise_error(described_class::Error, /memory:\/\/, redis:\/\/ or valkey:\/\//)
      end

      it "refuses an empty URL" do
        allow(Postal::Config.protection).to receive(:counter_store).and_return("")
        described_class.reset!

        expect { described_class.store }.to raise_error(described_class::Error)
      end
    end

    describe "choosing a quota store" do
      it "falls back to the counter store when no quota store is configured" do
        allow(Postal::Config.protection).to receive(:quota_store).and_return("")
        allow(Postal::Config.protection).to receive(:counter_store).and_return("redis://example.com:6379/0")
        described_class.reset!

        expect(described_class.quota_store).to be_a(described_class::Shared)
      end

      it "builds an isolated store when a quota store is configured" do
        allow(Postal::Config.protection).to receive(:quota_store).and_return("redis://quota.example.com:6379/0")
        allow(Postal::Config.protection).to receive(:counter_store).and_return("memory://")
        described_class.reset!

        expect(described_class.quota_store).to be_a(described_class::Shared)
        expect(described_class.store).to be_a(described_class::Memory)
      end
    end

    describe ".check_quota" do
      let(:credential) { instance_double(Credential, id: 42, options: {}) }

      before do
        allow(Postal::Config.protection).to receive(:api_send_limit).and_return(2)
        allow(Postal::Config.protection).to receive(:api_send_period).and_return(60)
        allow(Postal::Config.protection).to receive(:reset_redeem_limit).and_return(2)
        allow(Postal::Config.protection).to receive(:reset_redeem_period).and_return(60)
        described_class.quota_store = described_class::Memory.new
      end

      it "counts uses per credential and refuses past the limit" do
        2.times { expect(described_class.check_quota(:api_send, credential)).to be_allowed }

        result = described_class.check_quota(:api_send, credential)
        expect(result).to be_exceeded
        expect(result.retry_after).to be_between(1, 60)
      end

      it "namespaces quota keys with the configured prefix" do
        expect(described_class.quota_store).to receive(:increment)
          .with("postal:limits:api-send:credential:42", limit: 2, period: 60)
          .and_return(described_class::Result.new(1, 2, 0))

        described_class.check_quota(:api_send, credential)
      end

      it "does nothing when the quota is disabled" do
        allow(Postal::Config.protection).to receive(:api_send_limit).and_return(0)
        expect(described_class.quota_store).not_to receive(:increment)

        expect(described_class.check_quota(:api_send, credential)).to eq described_class::UNLIMITED
      end

      it "does nothing while protection is switched off" do
        allow(Postal::Config.protection).to receive(:enabled).and_return(false)
        expect(described_class.quota_store).not_to receive(:increment)

        expect(described_class.check_quota(:api_send, credential)).to eq described_class::UNLIMITED
      end

      it "honours a per-credential limit override" do
        allow(credential).to receive(:options).and_return({ "send_limit" => 1 })

        expect(described_class.check_quota(:api_send, credential)).to be_allowed
        expect(described_class.check_quota(:api_send, credential)).to be_exceeded
      end

      it "honours a per-credential period override" do
        allow(credential).to receive(:options).and_return({ "send_limit" => 5, "send_period" => 120 })
        expect(described_class.quota_store).to receive(:increment)
          .with("postal:limits:api-send:credential:42", limit: 5, period: 120)
          .and_return(described_class::Result.new(1, 5, 0))

        described_class.check_quota(:api_send, credential)
      end

      it "falls back safely when the options are not a hash" do
        allow(credential).to receive(:options).and_return(nil)

        2.times { expect(described_class.check_quota(:api_send, credential)).to be_allowed }
        expect(described_class.check_quota(:api_send, credential)).to be_exceeded
      end

      it "counts token redemption per client address" do
        2.times { expect(described_class.check_quota(:reset_redeem, "1.2.3.4")).to be_allowed }
        expect(described_class.check_quota(:reset_redeem, "1.2.3.4")).to be_exceeded
        expect(described_class.check_quota(:reset_redeem, "5.6.7.8")).to be_allowed
      end
    end
  end

end
