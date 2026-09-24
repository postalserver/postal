# frozen_string_literal: true

require "rails_helper"

describe Postal::Telemetry do
  before { described_class.shutdown }
  after { described_class.shutdown }

  context "when telemetry is not configured" do
    before { allow(Postal::Config.telemetry).to receive(:url).and_return(nil) }

    it "is disabled and records nothing" do
      expect(described_class).not_to receive(:publisher)
      expect(described_class.record("postal_test")).to be false
    end
  end

  context "when telemetry is configured" do
    let(:publisher) { instance_double(Postal::Telemetry::Publisher, publish: true) }

    before do
      allow(Postal::Config.telemetry).to receive(:url).and_return("json+http://vector:8686")
      allow(described_class).to receive(:publisher).and_return(publisher)
    end

    it "buffers a sample with string labels and never blocks" do
      expect(publisher).to receive(:publish) do |sample|
        expect(sample.name).to eq "postal_messages_total"
        expect(sample.labels).to eq("type" => "incoming")
        expect(sample.value).to eq 1
      end

      expect(described_class.increment("postal_messages_total", type: :incoming)).to be true
    end

    it "never raises when the publisher fails" do
      allow(publisher).to receive(:publish).and_raise("buffer gone")

      expect(described_class.record("postal_test")).to be false
    end
  end
end

describe Postal::Telemetry::Publisher do
  let(:client) { instance_double(Postal::Telemetry::Client) }
  let(:logger) { instance_double(Logger, warn: nil) }
  let(:samples) { Array.new(5) { |i| Postal::Telemetry::Sample.new("m", { "i" => i.to_s }, i, i) } }

  before do
    allow(Postal::Config.telemetry).to receive(:interval).and_return(3600)
    allow(Postal::Config.telemetry).to receive(:batch_size).and_return(2)
    allow(Postal::Config.telemetry).to receive(:queue_size).and_return(10)
  end

  subject(:publisher) { described_class.new(client: client, logger: logger) }

  after { publisher.stop }

  it "writes the buffer in batches" do
    expect(client).to receive(:write).exactly(3).times.and_return(2, 2, 1)

    samples.each { |sample| publisher.publish(sample) }

    expect(publisher.flush).to eq 5
  end

  it "drops the oldest samples when the buffer is full, counting them" do
    allow(Postal::Config.telemetry).to receive(:queue_size).and_return(3)

    samples.each { |sample| publisher.publish(sample) }

    expect(publisher.dropped).to eq 2
  end

  it "does not raise when a write fails" do
    allow(client).to receive(:write).and_raise("backend down")
    publisher.publish(samples.first)

    expect { publisher.flush }.not_to raise_error
  end
end
