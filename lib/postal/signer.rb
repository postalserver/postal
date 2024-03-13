# frozen_string_literal: true

require "base64"
module Postal
  class Signer

    # Create a new Signer
    #
    # @param [OpenSSL::PKey::RSA] private_key The private key to use for signing
    # @return [Signer]
    def initialize(private_key)
      @private_key = private_key
    end

    # Return the private key
    #
    # @return [OpenSSL::PKey::RSA]
    attr_reader :private_key

    # Return the public key for the private key
    #
    # @return [OpenSSL::PKey::RSA]
    def public_key
      @private_key.public_key
    end

    # Sign the given data
    #
    # @param [String] data The data to sign
    # @return [String] The signature
    def sign(data)
      private_key.sign(OpenSSL::Digest.new("SHA256"), data)
    end

    # Sign the given data and return a Base64-encoded signature
    #
    # @param [String] data The data to sign
    # @return [String] The Base64-encoded signature
    def sign64(data)
      Base64.strict_encode64(sign(data))
    end

    # Return a JWK for the private key
    #
    # @return [JWT::JWK] The JWK
    def jwk
      @jwk ||= JWT::JWK.new(private_key, { use: "sig", alg: "RS256" })
    end

    # Sign the given data using SHA1 (for legacy use)
    #
    # @param [String] data The data to sign
    # @return [String] The signature
    def sha1_sign(data)
      private_key.sign(OpenSSL::Digest.new("SHA1"), data)
    end

    # Sign the given data using SHA1 (for legacy use) and return a Base64-encoded string
    #
    # @param [String] data The data to sign
    # @return [String] The signature
    def sha1_sign64(data)
      Base64.strict_encode64(sha1_sign(data))
    end

  end
end
