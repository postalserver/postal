# frozen_string_literal: true

require "rails_helper"
module Postal

  RSpec.describe Signer do
    STATIC_PRIVATE_KEY = OpenSSL::PKey::RSA.new(2048) # rubocop:disable Lint/ConstantDefinitionInBlock

    subject(:signer) { described_class.new(STATIC_PRIVATE_KEY) }

    describe "#private_key" do
      it "returns the private key" do
        expect(signer.private_key).to eq(STATIC_PRIVATE_KEY)
      end
    end

    describe "#public_key" do
      it "returns the public key" do
        expect(signer.public_key.to_s).to eq(STATIC_PRIVATE_KEY.public_key.to_s)
      end
    end

    describe "#sign" do
      it "returns a valid signature" do
        data = "hello world!"
        signature = signer.sign(data)
        expect(signature).to be_a(String)
        verification = STATIC_PRIVATE_KEY.public_key.verify(OpenSSL::Digest.new("SHA256"),
                                                            signature,
                                                            data)
        expect(verification).to be true
      end
    end

    describe "#sign64" do
      it "returns a valid Base64-encoded signature" do
        data = "hello world!"
        signature = signer.sign64(data)
        expect(signature).to be_a(String)
        verification = STATIC_PRIVATE_KEY.public_key.verify(OpenSSL::Digest.new("SHA256"),
                                                            Base64.strict_decode64(signature),
                                                            data)
        expect(verification).to be true
      end
    end

    describe "#jwk" do
      it "returns a valid JWK" do
        jwk = signer.jwk
        expect(jwk).to be_a(JWT::JWK::RSA)
      end
    end

    describe "#sha1_sign" do
      it "returns a valid signature" do
        data = "hello world!"
        signature = signer.sha1_sign(data)
        expect(signature).to be_a(String)
        verification = STATIC_PRIVATE_KEY.public_key.verify(OpenSSL::Digest.new("SHA1"),
                                                            signature,
                                                            data)
        expect(verification).to be true
      end
    end

    describe "#sha1_sign64" do
      it "returns a valid Base64-encoded signature" do
        data = "hello world!"
        signature = signer.sha1_sign64(data)
        expect(signature).to be_a(String)
        verification = STATIC_PRIVATE_KEY.public_key.verify(OpenSSL::Digest.new("SHA1"),
                                                            Base64.strict_decode64(signature),
                                                            data)
        expect(verification).to be true
      end
    end
  end

end
