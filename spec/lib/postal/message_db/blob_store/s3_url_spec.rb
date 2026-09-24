# frozen_string_literal: true

require "rails_helper"

# The connection details for an S3-compatible store are given in blob_store.url.
# Unlike the rest of the backend this needs no bucket to exist, so it is exercised
# without MinIO — which is why it is not in the spec that is gated on MINIO_URL.
RSpec.describe Postal::MessageDB::BlobStore::S3 do
  describe "credentials given in the URL" do
    it "decodes them, because a secret contains characters which a URL must encode" do
      store = described_class.new(URI.parse("s3://AKIA%2FXX:se%2Fcret%2Bkey%3D@bucket/prefix"))

      options = store.send(:client_options)

      expect(options[:access_key_id]).to eq "AKIA/XX"
      expect(options[:secret_access_key]).to eq "se/cret+key="
    end

    it "prefers an explicit query parameter over the URL userinfo" do
      store = described_class.new(URI.parse("s3://user:password@bucket/prefix?access_key_id=from-query"))

      options = store.send(:client_options)

      expect(options[:access_key_id]).to eq "from-query"
      expect(options[:secret_access_key]).to eq "password"
    end
  end

  describe "the endpoint and path style" do
    it "translates path_style into the option the SDK expects and defaults the region" do
      store = described_class.new(URI.parse("s3://bucket/prefix?endpoint=http://minio:9000&path_style=1"))

      options = store.send(:client_options)

      expect(options[:force_path_style]).to be true
      expect(options[:endpoint]).to eq "http://minio:9000"
      expect(options[:region]).to eq "us-east-1"
    end
  end
end
