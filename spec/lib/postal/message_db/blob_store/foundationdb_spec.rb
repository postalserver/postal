# frozen_string_literal: true

require "rails_helper"

# FoundationDB is a distributed store, so this is only exercised where a cluster
# is reachable. Unlike the other backends it cannot be faked: the client library
# has to be loadable and the cluster file has to name something that answers, so
# the contract is covered by the filesystem store on a machine without one.
RSpec.describe Postal::MessageDB::BlobStore::FoundationDB do
  # The cluster file names the coordinators. The client library must also be
  # findable, which is what LD_LIBRARY_PATH is for in the image.
  let(:cluster_file) { ENV["FDB_CLUSTER_FILE"].to_s }

  subject(:store) { described_class.new }

  before do
    skip "set FDB_CLUSTER_FILE (and LD_LIBRARY_PATH) to run the FoundationDB blob store spec" if cluster_file.empty?
  end

  it "round-trips a body, and removes it" do
    key = store.store("a body which lives in FoundationDB")

    expect(store.retrieve(key)).to eq "a body which lives in FoundationDB"
    expect(store.delete(key)).to be true
    expect(store.retrieve(key)).to be_nil
  end

  it "round-trips a body which is empty" do
    key = store.store("")

    expect(store.retrieve(key)).to eq ""
  end

  it "returns nil for a key which was never stored" do
    expect(store.retrieve("no-such-key")).to be_nil
  end

  it "does not raise when a key which is not present is deleted" do
    expect(store.delete("no-such-key")).to be true
  end
end
