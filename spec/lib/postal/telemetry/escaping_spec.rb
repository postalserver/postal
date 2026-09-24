# frozen_string_literal: true

require "rails_helper"

describe Postal::Telemetry::Escaping do
  describe ".prometheus_label_value" do
    it "escapes backslash, quote and newline (backslash first)" do
      expect(described_class.prometheus_label_value("a\\b\"c\nd")).to eq "a\\\\b\\\"c\\nd"
    end

    it "leaves ordinary text alone" do
      expect(described_class.prometheus_label_value("acme.example.com")).to eq "acme.example.com"
    end
  end

  describe ".prometheus_metric_name" do
    it "accepts a valid name" do
      expect(described_class.prometheus_metric_name("postal_messages_total")).to eq "postal_messages_total"
    end

    it "rejects a name a scraper would drop" do
      expect { described_class.prometheus_metric_name("postal messages") }.to raise_error(Postal::Error)
    end
  end

  describe ".prometheus_label_name" do
    it "rejects a name with a dash" do
      expect { described_class.prometheus_label_name("server-id") }.to raise_error(Postal::Error)
    end
  end

  describe ".influx_measurement" do
    it "escapes spaces and commas" do
      expect(described_class.influx_measurement("a b,c")).to eq "a\\ b\\,c"
    end
  end

  describe ".influx_key" do
    it "escapes spaces, commas and equals" do
      expect(described_class.influx_key("a=b,c d")).to eq "a\\=b\\,c\\ d"
    end
  end
end

describe Postal::Telemetry::Client do
  it "renders prometheus samples with escaped labels" do
    sample = Postal::Telemetry::Sample.new("postal_messages_total", { "server" => "a\"b" }, 3, 1_704_067_200_000)
    encoded = described_class.new("prometheus+http://vm:8428").send(:encode, [sample])

    expect(encoded).to eq 'postal_messages_total{server="a\"b"} 3 1704067200000'
  end

  it "renders influx samples in line protocol" do
    sample = Postal::Telemetry::Sample.new("postal_messages_total", { "server" => "acme" }, 3, 1_704_067_200)
    encoded = described_class.new("influx+http://influx:8086/postal").send(:encode, [sample])

    expect(encoded).to eq "postal_messages_total,server=acme value=3 1704067200000000\n"
  end

  it "renders json samples as one object per line" do
    sample = Postal::Telemetry::Sample.new("postal_messages_total", { "server" => "acme" }, 3, 1_704_067_200_000)
    encoded = described_class.new("json+http://vector:8686").send(:encode, [sample])

    expect(JSON.parse(encoded)).to eq(
      "name" => "postal_messages_total", "labels" => { "server" => "acme" },
      "value" => 3, "timestamp" => 1_704_067_200_000
    )
  end
end
