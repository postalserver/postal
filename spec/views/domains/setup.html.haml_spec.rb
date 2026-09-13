# frozen_string_literal: true

require "rails_helper"

RSpec.describe "domains/setup", type: :view do
  let(:user) { create(:user, admin: true) }
  let(:organization) { create(:organization, owner: user) }
  let(:domain) { create(:domain, owner: organization, dkim_status: "OK") }

  before do
    assign(:organization, organization)
    assign(:domain, domain)
    assign(:server, nil)
    without_partial_double_verification do
      allow(view).to receive(:organization).and_return(organization)
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:page_title).and_return(["Postal"])
    end
  end

  context "when no key change is in progress" do
    it "shows the active record and offers regeneration" do
      render
      expect(rendered).to include(domain.dkim_record_name)
      expect(rendered).to include(domain.dkim_record)
      expect(rendered).to include("Regenerate DKIM key")
      expect(rendered).to_not include("Key change in progress")
      expect(rendered).to_not include("Cancel new DKIM key")
    end
  end

  context "when a key change is in progress" do
    before do
      domain.regenerate_dkim_key!
    end

    it "shows both the current and the new record" do
      render
      expect(rendered).to include(domain.dkim_record_name)
      expect(rendered).to include(domain.dkim_record)
      expect(rendered).to include(domain.pending_dkim_record_name)
      expect(rendered).to include(domain.pending_dkim_record)
    end

    it "labels which record is active and which must be added" do
      render
      expect(rendered).to include("Key change in progress")
      expect(rendered).to include("Keep this record exactly as it is")
      expect(rendered).to include("Add this record as well")
    end

    it "tells the user to add the new record rather than replace the old one" do
      render
      expect(rendered).to include("alongside the record above rather than replacing it")
    end

    it "does not describe the active record as one which needs adding" do
      render
      expect(rendered).to_not include("You need to add a new TXT record")
    end

    it "offers cancellation instead of another regeneration" do
      render
      expect(rendered).to include("Cancel new DKIM key")
      expect(rendered).to_not include("Regenerate DKIM key")
    end

    it "does not claim the DKIM record is fully good" do
      render
      expect(rendered).to_not include("Your DKIM record looks good!")
    end
  end
end
