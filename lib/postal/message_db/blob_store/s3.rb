# frozen_string_literal: true

require "securerandom"

module Postal
  module MessageDB
    module BlobStore
      #
      # Stores blobs as objects in an S3-compatible bucket (AWS S3, MinIO,
      # Ceph, ...), named by s3://bucket/prefix.
      #
      # Connection details come from the URL query and, for anything not given
      # there, from the standard AWS environment and configuration:
      #
      #   s3://bucket/prefix?region=eu-west-1
      #   s3://key:secret@bucket/prefix?endpoint=http://minio:9000&path_style=1
      #
      class S3

        def initialize(uri)
          @bucket = uri.host.to_s
          @prefix = uri.path.to_s.delete_prefix("/").delete_suffix("/")
          raise Postal::Error, "An S3 bucket must be given in blob_store.url" if @bucket.empty?

          @options = uri.query ? URI.decode_www_form(uri.query).to_h : {}
          @options["access_key_id"] ||= decoded(uri.user)
          @options["secret_access_key"] ||= decoded(uri.password)
        end

        #
        # Store the data and return the key it can be retrieved with.
        #
        def store(data)
          key = shards(BlobStore.generate_key).join("/")
          client.put_object(bucket: @bucket, key: key, body: data)
          key
        end

        #
        # Return the data for a key, or nil if it is not present.
        #
        def retrieve(key)
          client.get_object(bucket: @bucket, key: key).body.read
        rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
          nil
        end

        #
        # Remove the data for a key if it is present.
        #
        def delete(key)
          client.delete_object(bucket: @bucket, key: key)
          true
        end

        private

        #
        # The object key for a new blob: the prefix, two shard directories so a
        # bucket does not end up with one huge flat listing, then the key.
        #
        def shards(key)
          [@prefix, key[0, 2], key[2, 2], key].reject { |part| part.nil? || part.empty? }
        end

        def client
          Postal.require_optional_gem("aws-sdk-s3", group: "s3")
          self.class.client(client_options)
        end

        #
        # The URL query is nearly a set of Aws::S3::Client options; only
        # path_style needs translating.
        #
        def client_options
          options = @options.transform_keys(&:to_sym)
          options[:force_path_style] = true if options.delete(:path_style).to_s.match?(/\A(1|true|yes)\z/i)
          options[:region] ||= "us-east-1"
          options
        end

        #
        # Userinfo in a URL is percent-encoded, and an AWS secret routinely
        # contains characters which have to be (+, /, =), so it is decoded before
        # use. Passing the encoded form through authenticates with the wrong
        # secret and fails.
        #
        def decoded(value)
          value.to_s.empty? ? nil : URI.decode_uri_component(value)
        end

        class << self

          #
          # One client per set of options per process.
          #
          def client(options)
            @clients ||= {}
            @clients[options] ||= ::Aws::S3::Client.new(**options.transform_keys(&:to_sym))
          end

        end

      end
    end
  end
end
