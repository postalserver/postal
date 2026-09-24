# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

describe Postal::MessageDB::BlobStore do
  describe ".build" do
    it "returns nil for the inline scheme" do
      allow(Postal::Config.blob_store).to receive(:url).and_return("inline://")
      expect(described_class.build).to be_nil
    end

    it "returns nil when nothing is configured" do
      allow(Postal::Config.blob_store).to receive(:url).and_return(nil)
      expect(described_class.build).to be_nil
    end

    it "raises for an unknown scheme" do
      allow(Postal::Config.blob_store).to receive(:url).and_return("carrier-pigeon://x")
      expect { described_class.build }.to raise_error(Postal::Error, /Unknown blob store scheme/)
    end

    it "builds a filesystem store from the URL" do
      allow(Postal::Config.blob_store).to receive(:url).and_return("filesystem:///var/lib/postal/blobs?depth=2")

      store = described_class.build
      expect(store).to be_a Postal::MessageDB::BlobStore::Filesystem
      expect(store.path).to eq "/var/lib/postal/blobs"
      expect(store.depth).to eq 2
    end

    it "builds an S3 store from the URL" do
      allow(Postal::Config.blob_store).to receive(:url).and_return("s3://bucket/prefix?region=eu-west-1")

      store = described_class.build
      expect(store).to be_a Postal::MessageDB::BlobStore::S3
    end
  end
end

describe Postal::MessageDB::BlobStore::Filesystem do
  # Dir.mktmpdir removes the directory (and anything inside it) itself, so the
  # tests never have to delete a computed path by hand.
  around do |example|
    Dir.mktmpdir("postal-blob-store") do |dir|
      @dir = dir
      example.run
    end
  end

  let(:dir) { @dir }
  subject(:store) { described_class.new(dir, 2) }

  it "requires a path" do
    expect { described_class.new(nil) }.to raise_error(Postal::Error, /path must be configured/)
  end

  it "stores and retrieves data" do
    key = store.store("hello world")
    expect(store.retrieve(key)).to eq "hello world"
  end

  it "returns nil when a key is unknown" do
    expect(store.retrieve("missing")).to be_nil
  end

  it "stores binary data byte for byte" do
    data = (0..255).to_a.pack("C*") * 4
    key = store.store(data)
    expect(store.retrieve(key)).to eq data
  end

  it "shards keys across the configured directory depth" do
    key = store.store("x")
    relative = store.send(:file_path, key).delete_prefix("#{dir}/")
    expect(relative.split("/").size).to eq 3
  end

  it "stores files at the top level when the depth is zero" do
    flat = described_class.new(dir, 0)
    key = flat.store("x")
    expect(File.dirname(flat.send(:file_path, key))).to eq dir
  end

  it "deletes stored data" do
    key = store.store("bye")
    store.delete(key)
    expect(store.retrieve(key)).to be_nil
  end

  it "does nothing when deleting an unknown key" do
    expect(store.delete("missing")).to be true
  end
end
