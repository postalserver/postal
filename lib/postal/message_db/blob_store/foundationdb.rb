# frozen_string_literal: true

require "securerandom"

module Postal
  module MessageDB
    module BlobStore
      #
      # Stores blobs in a FoundationDB cluster.
      #
      # FoundationDB is a distributed ordered key-value store with ACID
      # transactions, so unlike the filesystem and S3 backends this store can
      # be shared by every node in a deployment: a blob written by one web worker
      # is readable by the next, which is what the message database itself already
      # assumes of its storage.
      #
      # There is no schema to migrate and no directory to create. Blobs live under
      # a configurable prefix so that a cluster shared with other data cannot
      # collide, and each write is a single transaction, so a value is either
      # wholly stored or not stored at all.
      #
      # Expiry is deliberately not implemented here. FoundationDB has no per-key
      # TTL, so retention of raw message bodies is the message database's job — it
      # already removes the rows which reference a blob.
      #
      class FoundationDB

        DEFAULT_PREFIX = "postal.blobs."

        # The binding is published per server release; this is the version the
        # cluster and the client library must agree on.
        DEFAULT_API_VERSION = 740

        attr_reader :prefix

        def initialize(prefix = nil, api_version: DEFAULT_API_VERSION)
          @prefix = prefix.to_s.empty? ? DEFAULT_PREFIX : prefix.to_s

          require "fdb"
          select_api_version(api_version)
        rescue LoadError
          raise Postal::Error, "The FoundationDB blob store requires the fdb gem and the " \
                               "FoundationDB client library. Enable it with " \
                               "`bundle config set --local with foundationdb` and install again."
        end

        #
        # Store the given data and return the key it can be retrieved with.
        #
        def store(data)
          key = BlobStore.generate_key
          database.transact do |transaction|
            transaction[key_for(key)] = data
          end
          key
        end

        #
        # Return the data stored for a key, or nil if it is not present.
        #
        def retrieve(key)
          database[key_for(key)]
        end

        #
        # Remove the data stored for a key if it is present.
        #
        def delete(key)
          database.transact do |transaction|
            transaction.clear(key_for(key))
          end
          true
        rescue StandardError
          false
        end

        private

        #
        # The API version is a property of the process rather than of a client, so
        # a second component selecting the same version is not an error and a
        # conflicting one is left alone rather than raised over.
        #
        def select_api_version(version)
          FDB.api_version(version)
        rescue StandardError
          nil
        end

        #
        # The cluster handle, opened from the standard FoundationDB environment
        # (`FDB_CLUSTER_FILE` or the default cluster file).
        #
        def database
          @database ||= FDB.open
        end

        def key_for(key)
          "#{@prefix}#{key}"
        end

      end
    end
  end
end
