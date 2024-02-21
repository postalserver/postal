# frozen_string_literal: true

require "rails_helper"

describe QueryString do
  it "works with a single item" do
    qs = described_class.new("to: test@example.com")
    expect(qs.hash["to"]).to eq "test@example.com"
  end

  it "works with a multiple items" do
    qs = described_class.new("to: test@example.com from: another@example.com")
    expect(qs.hash["to"]).to eq "test@example.com"
    expect(qs.hash["from"]).to eq "another@example.com"
  end

  it "does not require a space after the field name" do
    qs = described_class.new("to:test@example.com from:another@example.com")
    expect(qs.hash["to"]).to eq "test@example.com"
    expect(qs.hash["from"]).to eq "another@example.com"
  end

  it "returns nil when it receives blank" do
    qs = described_class.new("to:[blank]")
    expect(qs.hash["to"]).to eq nil
  end

  it "handles dates with spaces" do
    qs = described_class.new("date: 2017-02-12 15:20")
    expect(qs.hash["date"]).to eq("2017-02-12 15:20")
  end

  it "returns an array for multiple items" do
    qs = described_class.new("to: test@example.com to: another@example.com")
    expect(qs.hash["to"]).to be_a(Array)
    expect(qs.hash["to"][0]).to eq "test@example.com"
    expect(qs.hash["to"][1]).to eq "another@example.com"
  end

  it "works with a z in the string" do
    qs = described_class.new("to: testaz@example.com")
    expect(qs.hash["to"]).to eq "testaz@example.com"
  end
end
