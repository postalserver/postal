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

    it "offers the permitted key sizes" do
      render
      expect(rendered).to include("Use the default")
      expect(rendered).to include("#{Domain::DKIM_KEY_SIZES.last} bits")
    end
  end

  context "when the record is too long for a single DNS string" do
    it "explains how to publish it as several strings" do
      render
      expect(rendered).to include("255 character limit")
      expect(rendered).to include(domain.dkim_record_chunks.first)
      expect(rendered).to include(domain.dkim_record_chunks.last)
    end
  end

  context "when the record fits in a single DNS string" do
    let(:domain) { create(:domain, owner: organization, dkim_status: "OK", dkim_key_size: 1024) }

    it "does not show the split form" do
      render
      expect(rendered).to_not include("255 character limit")
    end
  end

  context "the DMARC record" do
    it "shows the record name and a recommended record" do
      render
      expect(rendered).to include(domain.dmarc_record_name)
      expect(rendered).to include(domain.dmarc_record)
    end

    it "makes clear that the policy is not managed by Postal" do
      render
      expect(rendered).to include("does not manage")
    end
  end

  context "the TLS-RPT record" do
    before do
      allow(Postal::Config.dns).to receive(:tls_rpt_address).and_return("tlsrpt@example.com")
    end

    it "shows the record name and the record" do
      render
      expect(rendered).to include(domain.tls_rpt_record_name)
      expect(rendered).to include(domain.tls_rpt_record)
    end
  end

  context "when no TLS-RPT destination is configured" do
    it "explains that nothing is published" do
      render
      expect(rendered).to include("No TLS-RPT destination is configured")
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
