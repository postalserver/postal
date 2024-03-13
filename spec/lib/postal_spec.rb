# frozen_string_literal: true

require "rails_helper"

RSpec.describe Postal do
  describe "#signer" do
    it "returns a signer with the installation's signing key" do
      expect(Postal.signer).to be_a(Signer)
      expect(Postal.signer.private_key.to_pem).to eq OpenSSL::PKey::RSA.new(File.read(Postal::Config.postal.signing_key_path)).to_pem
    end
  end
end
