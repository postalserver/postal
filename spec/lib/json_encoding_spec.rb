# frozen_string_literal: true

require "rails_helper"

# Active Support 7.2 calls `JSON.generate(..., quirks_mode: true)` and
# `JSON.parse(json, quirks_mode: true)`. The json gem removed `quirks_mode` in
# 3.0, so an unpinned json resolves to 3.x and every `to_json` in the app raises
# ArgumentError - webhook payloads and JSON API responses included. The Gemfile
# pins json to < 3 because of this; these examples fail loudly if that pin is
# removed before we are on a Rails version that no longer passes the option.
RSpec.describe "JSON encoding" do
  it "encodes a hash" do
    expect({ "a" => 1 }.to_json).to eq '{"a":1}'
  end

  it "encodes nested structures with mixed types" do
    payload = { "event" => "MessageSent", "timestamp" => 1.5, "payload" => { "list" => [1, "two", nil, true] } }
    expect(JSON.parse(payload.to_json)).to eq payload
  end

  it "round trips through Active Support's encoder" do
    payload = { "uuid" => "abc-123", "nested" => { "x" => [1, 2] } }
    expect(ActiveSupport::JSON.decode(ActiveSupport::JSON.encode(payload))).to eq payload
  end

  it "encodes a bare value, which is what quirks_mode allowed" do
    expect(ActiveSupport::JSON.encode("hello")).to eq '"hello"'
    expect(ActiveSupport::JSON.encode(42)).to eq "42"
  end

  it "encodes times the way the webhook payload relies on" do
    expect(Time.at(1_700_000_000).utc.to_f.to_json).to eq "1700000000.0"
  end
end
