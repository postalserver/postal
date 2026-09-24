# frozen_string_literal: true

require "fileutils"
require "securerandom"

module Postal
  module MessageDB
    module BlobStore
      #
      # Stores blobs as files on disk. Each blob is written under a random key,
      # sharded across a configurable number of directory levels so a single
      # directory does not grow without bound.
      #
      class Filesystem

        attr_reader :path
        attr_reader :depth

        def initialize(path, depth = 2)
          if path.nil? || path.to_s.empty?
            raise Postal::Error, "A path must be configured for the filesystem blob store"
          end

          @path = path.to_s
          @depth = [depth.to_i, 0].max
        end

        def self.valid_key?(key)
          BlobStore.valid_key?(key)
        end

        #
        # Store the given data and return the key it can be retrieved with.
        #
        def store(data)
          key = BlobStore.generate_key
          file = file_path(key)
          FileUtils.mkdir_p(File.dirname(file))
          File.binwrite(file, data)
          key
        end

        #
        # Return the data stored for a key, or nil if it is not present.
        #
        def retrieve(key)
          return nil unless self.class.valid_key?(key)

          file = file_path(key)
          File.exist?(file) ? File.binread(file) : nil
        end

        #
        # Remove the data stored for a key if it is present.
        #
        def delete(key)
          return true unless self.class.valid_key?(key)

          FileUtils.rm_f(file_path(key))
          true
        rescue SystemCallError
          false
        end

        private

        #
        # The absolute path a key is stored at, sharding the key across `depth`
        # two-character directory levels.
        #
        def file_path(key)
          key = key.to_s
          unless self.class.valid_key?(key)
            raise Postal::Error, "Invalid blob key"
          end

          shards = (0...@depth).map { |i| key[(i * 2), 2].to_s }
          File.join(@path, *shards, key)
        end

      end
    end
  end
end
