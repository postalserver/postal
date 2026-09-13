# frozen_string_literal: true

require "rails_helper"

RSpec.describe ControlAPIKey do
  describe ".issue!" do
    it "returns a plaintext token once and persists only its digest" do
      key, token = described_class.issue!(name: "Control panel", scopes: ["organizations:read"])

      expect(token).to start_with("postal_cp_")
      expect(key.token_digest).to eq(Digest::SHA256.hexdigest(token))
      expect(key.attributes.values).not_to include(token)
    end
  end

  describe ".authenticate" do
    it "accepts an active token and updates last use" do
      key, token = described_class.issue!(name: "Control panel", scopes: ["organizations:read"])

      expect(described_class.authenticate(token)).to eq(key)
      expect(key.reload.last_used_at).to be_present
    end

    it "rejects revoked and expired tokens" do
      revoked, revoked_token = described_class.issue!(name: "Revoked", scopes: ["organizations:read"])
      _expired, expired_token = described_class.issue!(name: "Expired", scopes: ["organizations:read"], expires_at: 1.minute.ago)
      revoked.update!(revoked_at: Time.current)

      expect(described_class.authenticate(revoked_token)).to be_nil
      expect(described_class.authenticate(expired_token)).to be_nil
    end
  end

  it "does not permit platform scope on an organization key" do
    expect do
      described_class.issue!(name: "Tenant", organization: create(:organization), scopes: ["platform:admin"])
    end.to raise_error(ActiveRecord::RecordInvalid)
  end
end
