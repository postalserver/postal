# frozen_string_literal: true

require "rails_helper"
require "stringio"

describe Postal::Metrics do
  before { described_class.reset! }
  after { described_class.reset! }

  describe ".record" do
    context "when the live metrics are disabled" do
      before { allow(Postal::Config.live_stats).to receive(:url).and_return("mysql://") }

      it "does not touch the store" do
        expect(Postal::Metrics::Store).not_to receive(:build)

        expect(described_class.record("postal_test", { server: "x" })).to be false
      end
    end

    context "when the live metrics are enabled" do
      let(:store) { instance_double(Postal::Metrics::Store::TimeSeries) }

      before do
        allow(Postal::Config.live_stats).to receive(:url).and_return("prometheus+http://vm:8428")
        allow(Postal::Metrics::Store).to receive(:build).and_return(store)
      end

      it "records to the store and publishes an event to subscribers" do
        events = Postal::Metrics::Broadcaster.subscribe
        expect(store).to receive(:record).with("postal_test", { server: "x" }, 2)

        expect(described_class.record("postal_test", { server: "x" }, 2)).to be true
        expect(events.pop).to include("name" => "postal_test", "value" => 2)
      ensure
        Postal::Metrics::Broadcaster.unsubscribe(events)
      end

      it "never raises when the store fails" do
        allow(store).to receive(:record).and_raise("store is down")

        expect(described_class.record("postal_test")).to be false
      end
    end
  end

  describe ".query" do
    it "returns nil when the live metrics are disabled" do
      allow(Postal::Config.live_stats).to receive(:url).and_return("mysql://")

      expect(described_class.query("postal_test")).to be_nil
    end

    it "reads from the store with the configured window" do
      store = instance_double(Postal::Metrics::Store::TimeSeries)
      allow(Postal::Config.live_stats).to receive(:url).and_return("prometheus+http://vm:8428")
      allow(Postal::Metrics::Store).to receive(:build).and_return(store)

      expect(store).to receive(:query).with("postal_test", {}, window: 3600)
      described_class.query("postal_test")
    end
  end
end

describe Postal::Metrics::Broadcaster do
  after { described_class.reset! }

  it "delivers published events to every subscriber" do
    first = described_class.subscribe
    second = described_class.subscribe

    described_class.publish("postal_test", { server: "x" }, 3)

    expect(first.pop).to include("name" => "postal_test", "labels" => { server: "x" }, "value" => 3)
    expect(second.pop).to include("value" => 3)
  end

  it "stops delivering after unsubscribing" do
    queue = described_class.subscribe
    described_class.unsubscribe(queue)

    described_class.publish("postal_test", {}, 1)

    expect(queue).to be_empty
  end
end

describe Postal::Metrics::Stream do
  it "writes events as server-sent events and stops when the source closes" do
    events = Queue.new
    events << { "name" => "postal_test", "labels" => { "server" => "x" }, "value" => 2, "time" => 123 }
    events.close

    io = StringIO.new
    described_class.new(io, events: events).run

    expect(io.string).to eq(
      %(data: {"name":"postal_test","labels":{"server":"x"},"value":2,"time":123}\n\n)
    )
  end
end
