# frozen_string_literal: true

require "rails_helper"

RSpec.describe ControlPlane::OutboundQuota do
  let(:organization) { create(:organization, monthly_outbound_limit: 2, quota_action: quota_action) }
  let(:server_a) { create(:server, organization: organization) }
  let(:server_b) { create(:server, organization: organization, name: "Mail Server B", permalink: "mail-server-b") }
  let(:quota_action) { "hold" }

  it "counts organization usage across servers rather than by credential or server" do
    first = described_class.reserve!(server_a, count: 2)
    second = described_class.reserve!(server_b, count: 1)

    expect(first).to be_allow
    expect(second).to be_hold
    expect(UsageRollup.last.value).to eq(3)
  end

  context "when configured to suspend" do
    let(:quota_action) { "suspend" }

    it "suspends the organization once the configured limit is exceeded" do
      described_class.reserve!(server_a, count: 2)
      decision = described_class.reserve!(server_b, count: 1)

      expect(decision).to be_suspend
      expect(organization.reload).to be_suspended
      expect(UsageRollup.last.value).to eq(2)
    end
  end

  context "when configured to monitor" do
    let(:quota_action) { "monitor" }

    it "records usage without blocking delivery" do
      described_class.reserve!(server_a, count: 2)

      expect(described_class.reserve!(server_b, count: 1)).to be_allow
    end
  end
end
