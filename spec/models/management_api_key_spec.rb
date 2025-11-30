# frozen_string_literal: true

require "rails_helper"

RSpec.describe ManagementAPIKey do
  describe "validations" do
    it "validates presence of name" do
      key = build(:management_api_key, name: nil)
      expect(key).not_to be_valid
      expect(key.errors[:name]).to include("can't be blank")
    end

    it "validates uniqueness of key" do
      existing = create(:management_api_key)
      new_key = build(:management_api_key)
      new_key.key = existing.key
      expect(new_key).not_to be_valid
      expect(new_key.errors[:key]).to include("has already been taken")
    end

    it "requires organization for non-super-admin keys" do
      key = build(:management_api_key, super_admin: false, organization: nil)
      expect(key).not_to be_valid
      expect(key.errors[:organization]).to include("is required for non-super-admin keys")
    end

    it "allows nil organization for super-admin keys" do
      key = build(:management_api_key, super_admin: true, organization: nil)
      expect(key).to be_valid
    end
  end

  describe "key generation" do
    it "generates a key with mgmt_ prefix on creation" do
      key = create(:management_api_key)
      expect(key.key).to start_with("mgmt_")
    end

    it "generates a key of correct length" do
      key = create(:management_api_key)
      # prefix (5) + 40 chars = 45
      expect(key.key.length).to eq(45)
    end

    it "does not regenerate key on update" do
      key = create(:management_api_key)
      original_key = key.key
      key.update!(name: "New Name")
      expect(key.key).to eq(original_key)
    end
  end

  describe ".authenticate" do
    it "returns key when valid" do
      key = create(:management_api_key)
      expect(described_class.authenticate(key.key)).to eq(key)
    end

    it "returns nil for invalid key" do
      expect(described_class.authenticate("invalid_key")).to be_nil
    end

    it "returns nil for blank key" do
      expect(described_class.authenticate("")).to be_nil
      expect(described_class.authenticate(nil)).to be_nil
    end

    it "returns nil for disabled key" do
      key = create(:management_api_key, :disabled)
      expect(described_class.authenticate(key.key)).to be_nil
    end

    it "returns nil for expired key" do
      key = create(:management_api_key, :expired)
      expect(described_class.authenticate(key.key)).to be_nil
    end
  end

  describe "#use!" do
    it "increments request count" do
      key = create(:management_api_key)
      expect { key.use!("127.0.0.1") }.to change { key.reload.request_count }.by(1)
    end

    it "updates last_used_at" do
      key = create(:management_api_key)
      expect { key.use!("127.0.0.1") }.to change { key.reload.last_used_at }
    end

    it "updates last_used_ip" do
      key = create(:management_api_key)
      key.use!("192.168.1.1")
      expect(key.reload.last_used_ip).to eq("192.168.1.1")
    end
  end

  describe "#active?" do
    it "returns true for enabled, non-expired key" do
      key = create(:management_api_key)
      expect(key.active?).to be true
    end

    it "returns false for disabled key" do
      key = create(:management_api_key, :disabled)
      expect(key.active?).to be false
    end

    it "returns false for expired key" do
      key = create(:management_api_key, :expired)
      expect(key.active?).to be false
    end
  end

  describe "#can_access_organization?" do
    let(:organization) { create(:organization) }
    let(:other_organization) { create(:organization) }

    it "returns true for super admin keys" do
      key = create(:management_api_key, :super_admin)
      expect(key.can_access_organization?(organization)).to be true
    end

    it "returns true for organization-scoped key with matching org" do
      key = create(:management_api_key, :organization_scoped, organization: organization)
      expect(key.can_access_organization?(organization)).to be true
    end

    it "returns false for organization-scoped key with different org" do
      key = create(:management_api_key, :organization_scoped, organization: organization)
      expect(key.can_access_organization?(other_organization)).to be false
    end
  end

  describe "#expired?" do
    it "returns false when expires_at is nil" do
      key = build(:management_api_key, expires_at: nil)
      expect(key.expired?).to be false
    end

    it "returns false when expires_at is in the future" do
      key = build(:management_api_key, expires_at: 1.day.from_now)
      expect(key.expired?).to be false
    end

    it "returns true when expires_at is in the past" do
      key = build(:management_api_key, expires_at: 1.day.ago)
      expect(key.expired?).to be true
    end
  end
end
