# frozen_string_literal: true

require "rails_helper"

RSpec.describe DomainsController, type: :controller do
  let(:user) { create(:user, admin: true) }
  let(:organization) { create(:organization, owner: user) }
  let(:server) { create(:server, organization: organization) }
  let(:domain) { create(:domain, owner: server, name: "example.com") }

  before do
    allow(controller).to receive(:logged_in?).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe "GET tls_reports" do
    it "renders the reports page for a domain which belongs to a server" do
      report = TLSReport.create!(domain: domain, report_id: "report-1")

      get :tls_reports, params: {
        org_permalink: organization.permalink,
        server_id: server.permalink,
        id: domain.uuid
      }

      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@reports).to_a).to eq [report]
    end

    it "renders the reports page for a domain which belongs to the organization" do
      organization_domain = create(:domain, owner: organization)
      report = TLSReport.create!(domain: organization_domain, report_id: "report-1")

      get :tls_reports, params: {
        org_permalink: organization.permalink,
        id: organization_domain.uuid
      }

      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@reports).to_a).to eq [report]
    end

    it "does not render the page for a domain which does not belong to the server" do
      elsewhere = create(:domain)

      expect do
        get :tls_reports, params: {
          org_permalink: organization.permalink,
          server_id: server.permalink,
          id: elsewhere.uuid
        }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
