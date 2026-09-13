# frozen_string_literal: true

require "rails_helper"

RSpec.describe "domains/index", type: :view do
  let(:user) { create(:user, admin: true) }
  let(:organization) { create(:organization, owner: user) }
  let(:domain) { create(:domain, owner: organization, dkim_status: "OK") }

  before do
    assign(:organization, organization)
    assign(:domains, [domain])
    assign(:server, nil)
    without_partial_double_verification do
      allow(view).to receive(:organization).and_return(organization)
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:page_title).and_return(["Postal"])
    end
  end

  context "when no key change is in progress" do
    it "does not flag a pending DKIM key" do
      render
      expect(rendered).to_not include("New DKIM key pending")
    end
  end

  context "when a key change is in progress" do
    before do
      domain.regenerate_dkim_key!
    end

    it "flags the domain as having a pending DKIM key" do
      render
      expect(rendered).to include("New DKIM key pending")
    end

    it "links the flag to the DNS setup page" do
      render
      expect(rendered).to include(setup_organization_domain_path(organization, domain))
    end

    it "still shows DKIM as OK because the active key is unaffected" do
      render
      expect(rendered).to include("domainList__check--ok")
    end
  end
end
