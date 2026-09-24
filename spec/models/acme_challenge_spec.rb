# frozen_string_literal: true

require "rails_helper"

RSpec.describe ACMEChallenge do
  describe ".store!" do
    it "stores the content for a token" do
      described_class.store!("a-token", "a-token.thumbprint")
      expect(described_class.content_for("a-token")).to eq "a-token.thumbprint"
    end

    it "replaces the content when the same token is stored again" do
      described_class.store!("a-token", "first")
      described_class.store!("a-token", "second")
      expect(described_class.content_for("a-token")).to eq "second"
      expect(described_class.count).to eq 1
    end
  end

  describe ".content_for" do
    it "returns nil for a token which was never stored" do
      expect(described_class.content_for("unknown")).to be_nil
    end

    it "returns nil for an expired challenge" do
      described_class.store!("a-token", "content", expires_at: 1.minute.ago)
      expect(described_class.content_for("a-token")).to be_nil
    end
  end

  describe ".prune!" do
    it "removes expired challenges and keeps those which are still live" do
      described_class.store!("expired", "content", expires_at: 1.minute.ago)
      described_class.store!("live", "content")
      described_class.prune!
      expect(described_class.pluck(:token)).to eq ["live"]
    end
  end
end
