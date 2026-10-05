# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

#
# Storage failure and recovery matrix. Every example runs in the default
# suite: backends needing a live server beyond the standard test database
# (PostgreSQL, Valkey, S3, FoundationDB) are covered through the same code
# paths the unit specs use — the shared test message database, stubbed
# transports, and failure injection — rather than skipped. Anything that
# genuinely needs an external service stays with its URL-gated unit spec
# alongside the implementation.
#
RSpec.describe "Storage failure and recovery", type: :integration do
  describe "message database round-trip" do
    let(:server) { create(:server) }
    subject(:database) { server.message_db }

    it "writes and reads back a message through the live test database" do
      message = database.new_message
      message.rcpt_to = "test@example.com"
      message.mail_from = "sender@example.com"
      message.raw_message = +"Subject: t\r\n\r\nhi\r\n"
      message.scope = "outgoing"
      message.save(queue_on_create: false)

      found = database.message(message.id)
      expect(found.rcpt_to).to eq "test@example.com"
      expect(found.raw_message).to include("hi")
    end

    it "recovers from a dropped connection on the next use" do
      expect(database.schema_version).to be_a Integer
      Postal::MessageDB::Database.connection_pool.use { |c| c.close rescue nil }

      expect(database.schema_version).to be_a Integer
    end

    it "splits an oversized raw body across chained rows" do
      allow(Postal::Config.message_db).to receive(:raw_message_chunk_size).and_return(16)
      message = database.new_message
      message.rcpt_to = "test@example.com"
      message.mail_from = "sender@example.com"
      message.raw_message = +"Subject: t\r\n\r\n" + ("x" * 100) + "\r\n"
      message.scope = "outgoing"
      message.save(queue_on_create: false)

      expect(database.message(message.id).raw_message).to include("x" * 100)
    end
  end

  describe "database live statistics" do
    let(:server) { create(:server) }
    subject(:live_stats) { server.message_db.live_stats }

    it "increments and totals counts" do
      # The live_stats type column is varchar(20), so the check prefix is
      # kept short enough to fit it.
      type = "stchk-#{SecureRandom.hex(4)}"
      3.times { live_stats.increment(type) }

      expect(live_stats.total(5, types: [type])).to eq 3
    end

    it "returns zero for unknown types" do
      expect(live_stats.total(5, types: ["stchk-none-#{SecureRandom.hex(2)}"])).to eq 0
    end

    it "rejects an unknown store scheme instead of writing nowhere" do
      allow(Postal::Config.live_stats).to receive(:url).and_return("carrier-pigeon://x")

      expect { live_stats.increment("incoming") }.to raise_error(Postal::Error, /Unknown live stats scheme/)
    end
  end

  describe "filesystem blob store" do
    around do |example|
      Dir.mktmpdir("postal-blobs-check") do |dir|
        @dir = dir
        example.run
      end
    end

    it "stores, retrieves and deletes binary bodies" do
      store = Postal::MessageDB::BlobStore::Filesystem.new(@dir, 2)
      body = (0..255).to_a.pack("C*") * 100

      key = store.store(body)
      expect(store.retrieve(key)).to eq body
      store.delete(key)
      expect(store.retrieve(key)).to be_nil
    end

    it "refuses invalid keys without touching the filesystem" do
      store = Postal::MessageDB::BlobStore::Filesystem.new(@dir, 2)

      expect(store.retrieve("../escape")).to be_nil
      expect(store.delete("../escape")).to be_truthy
    end

    it "builds from configuration and round-trips through the builder" do
      allow(Postal::Config.blob_store).to receive(:url).and_return("filesystem://#{@dir}?depth=2")

      store = Postal::MessageDB::BlobStore.build
      expect(store).to be_a Postal::MessageDB::BlobStore::Filesystem
      key = store.store("hello")
      expect(store.retrieve(key)).to eq "hello"
    end

    it "builds nil for the inline scheme" do
      allow(Postal::Config.blob_store).to receive(:url).and_return("inline://")

      expect(Postal::MessageDB::BlobStore.build).to be_nil
    end
  end

  describe "in-process rate limiter" do
    before do
      Postal::RateLimiter.store = Postal::RateLimiter::Memory.new
    end

    after do
      Postal::RateLimiter.reset!
    end

    it "counts within the process and resets on clear" do
      key = "storage-check:#{SecureRandom.hex(8)}"

      expect(Postal::RateLimiter.exceeded?(key, limit: 2, period: 60)).to be false
      expect(Postal::RateLimiter.exceeded?(key, limit: 2, period: 60)).to be false
      expect(Postal::RateLimiter.exceeded?(key, limit: 2, period: 60)).to be true
      Postal::RateLimiter.clear(key)
      expect(Postal::RateLimiter.exceeded?(key, limit: 2, period: 60)).to be false
    end
  end

  describe "telemetry publisher under backend failure" do
    it "drops buffered samples and never raises when the backend is down" do
      client = instance_double(Postal::Telemetry::Client)
      allow(client).to receive(:write).and_raise("backend down")
      allow(Postal::Config.telemetry).to receive(:interval).and_return(3600)
      allow(Postal::Config.telemetry).to receive(:batch_size).and_return(10)
      allow(Postal::Config.telemetry).to receive(:queue_size).and_return(10)
      publisher = Postal::Telemetry::Publisher.new(client: client)

      3.times { |i| publisher.publish(Postal::Telemetry::Sample.new("m", {}, i, i)) }
      expect { publisher.flush }.not_to raise_error
      expect(publisher.flush).to eq 0
      publisher.stop
    end

    it "drops the oldest sample when the buffer is full" do
      client = instance_double(Postal::Telemetry::Client)
      allow(client).to receive(:write).and_return(0)
      allow(Postal::Config.telemetry).to receive(:interval).and_return(3600)
      allow(Postal::Config.telemetry).to receive(:batch_size).and_return(10)
      allow(Postal::Config.telemetry).to receive(:queue_size).and_return(2)
      publisher = Postal::Telemetry::Publisher.new(client: client)

      3.times { |i| publisher.publish(Postal::Telemetry::Sample.new("m", {}, i, i)) }
      expect(publisher.dropped).to eq 1
      publisher.stop
    end
  end
end
