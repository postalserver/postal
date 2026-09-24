# frozen_string_literal: true

require "rails_helper"
require "securerandom"

describe Postal::MessageDB::LiveStats::Aerospike do
  let(:hosts) { ENV["AEROSPIKE_HOSTS"].to_s }
  subject(:store) { described_class.new(hosts, "test", "postal_test") }

  before do
    skip "the optional aerospike group is not installed" unless aerospike_available?
    skip "set AEROSPIKE_HOSTS to run the Aerospike live stats spec" if hosts.empty?
  end

  def aerospike_available?
    require "aerospike"
    true
  rescue LoadError
    false
  end

  it "increments and totals the counts for a type" do
    type = "spec-#{SecureRandom.hex(4)}"

    store.increment(type)
    store.increment(type)

    expect(store.total(5, types: [type])).to eq 2
  end

  it "returns zero for types with no counts" do
    expect(store.total(5, types: ["absent-#{SecureRandom.hex(4)}"])).to eq 0
  end

  it "counts each type separately" do
    incoming = "spec-#{SecureRandom.hex(4)}"
    outgoing = "spec-#{SecureRandom.hex(4)}"

    store.increment(incoming)
    store.increment(incoming)
    store.increment(incoming)
    store.increment(outgoing)

    expect(store.total(5, types: [incoming, outgoing])).to eq 4
  end
end
