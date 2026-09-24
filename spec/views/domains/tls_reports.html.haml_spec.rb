# frozen_string_literal: true

require "rails_helper"

RSpec.describe "domains/tls_reports", type: :view do
  let(:user) { create(:user, admin: true) }
  let(:organization) { create(:organization, owner: user) }
  let(:domain) { create(:domain, owner: organization, name: "example.com") }

  let(:reports) { [] }
  let(:failure_counts) { {} }

  before do
    assign(:organization, organization)
    assign(:domain, domain)
    assign(:server, nil)
    assign(:reports, reports)
    assign(:failure_counts, failure_counts)
    without_partial_double_verification do
      allow(view).to receive(:organization).and_return(organization)
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:page_title).and_return(["Postal"])
    end
  end

  def report(attributes = {})
    TLSReport.new({
      report_id: "report-1",
      organization_name: "Example Reporting Organization",
      submitter: "sender.example.net",
      successful_session_count: 1200,
      failed_session_count: 3,
      date_start: Time.zone.parse("2026-09-18T00:00:00Z"),
      date_end: Time.zone.parse("2026-09-19T00:00:00Z")
    }.merge(attributes))
  end

  context "when no reports have been received" do
    it "says so" do
      render
      expect(rendered).to include("No TLS reports have been received for this domain.")
    end
  end

  context "when reports have been received" do
    let(:reports) { [report] }

    it "shows what was reported and by whom" do
      render
      expect(rendered).to include("Example Reporting Organization")
      expect(rendered).to include("sender.example.net")
    end

    it "shows the session counts" do
      render
      expect(rendered).to include("1,200")
      expect(rendered).to include("3")
    end

    it "shows the period the report covers" do
      render
      expect(rendered).to include("2026-09-18 to 2026-09-19")
    end

    it "says when no failures have been reported" do
      render
      expect(rendered).to include("No failures have been reported for this domain.")
    end
  end

  context "when failures have been reported" do
    let(:reports) { [report] }
    let(:failure_counts) { { "starttls-not-supported" => 2, "certificate-expired" => 5 } }

    it "shows each reason and how many sessions failed for it" do
      render
      expect(rendered).to include("certificate-expired")
      expect(rendered).to include("starttls-not-supported")
    end

    it "shows the reason which accounts for the most failures first" do
      render
      expect(rendered.index("certificate-expired")).to be < rendered.index("starttls-not-supported")
    end
  end

  context "when a report carries markup in a field it controls" do
    let(:reports) do
      [report(organization_name: "<script>alert(1)</script>",
              submitter: "<img src=x onerror=alert(1)>")]
    end

    let(:failure_counts) { { "<script>alert(1)</script>" => 3 } }

    it "escapes it rather than rendering it" do
      render

      expect(rendered).to_not include("<script>alert(1)</script>")
      expect(rendered).to_not include("<img src=x onerror=alert(1)>")
      expect(rendered).to include("&lt;script&gt;")
    end
  end
end
