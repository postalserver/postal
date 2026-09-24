# frozen_string_literal: true

require "rails_helper"
require "cgi"
require "uri"

describe Postal::MessageDB::BlobStore::S3 do
  let(:endpoint) { ENV["MINIO_URL"].to_s }
  let(:bucket) { "postal-blobs" }

  subject(:store) { described_class.new(URI.parse(url)) }

  before do
    skip "set MINIO_URL to run the S3 blob store spec" if endpoint.empty?

    ensure_bucket
  end

  it "stores, retrieves and deletes an object" do
    key = store.store("hello world")

    expect(store.retrieve(key)).to eq "hello world"

    store.delete(key)
    expect(store.retrieve(key)).to be_nil
  end

  it "stores binary data byte for byte" do
    data = (0..255).to_a.pack("C*") * 4
    key = store.store(data)

    expect(store.retrieve(key)).to eq data
  end

  private

  def url
    uri = URI.parse(endpoint)
    "s3://postal:postal123@#{uri.host}:#{uri.port}/#{bucket}" \
      "?region=us-east-1&path_style=1&endpoint=#{CGI.escape(endpoint)}"
  end

  def ensure_bucket
    require "aws-sdk-s3"
    s3.create_bucket(bucket: bucket)
  rescue Aws::S3::Errors::BucketAlreadyOwnedByYou, Aws::S3::Errors::BucketAlreadyExists
    nil
  end

  def s3
    Aws::S3::Client.new(region: "us-east-1", endpoint: endpoint, force_path_style: true,
                        access_key_id: "postal", secret_access_key: "postal123")
  end
end
