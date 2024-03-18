# frozen_string_literal: true

require "rails_helper"

RSpec.describe Postal do
  describe "#signer" do
    it "returns a signer with the installation's signing key" do
      expect(Postal.signer).to be_a(Postal::Signer)
      expect(Postal.signer.private_key.to_pem).to eq OpenSSL::PKey::RSA.new(File.read(Postal::Config.postal.signing_key_path)).to_pem
    end
  end

  describe "#change_database_connection_pool_size" do
    it "changes the connection pool size" do
      expect { Postal.change_database_connection_pool_size(8) }.to change { ActiveRecord::Base.connection_pool.size }.from(5).to(8)
    end
  end
end
