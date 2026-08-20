# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Read-only organization access", type: :request do
  let(:admin) { create(:user, admin: true) }
  let(:organization) { create(:organization, owner: admin) }
  let(:readonly_user) { create(:user, email_address: "readonly@example.com") }
  let(:server) { create(:server, organization: organization) }

  before do
    create(:organization_user, organization: organization, user: readonly_user, read_only: true)
    post "/login", params: { email_address: readonly_user.email_address, password: "passw0rd" }
  end

  describe "GET requests" do
    it "allows viewing the organization servers" do
      get "/org/#{organization.permalink}/servers/#{server.permalink}"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "write requests" do
    it "blocks creating a credential" do
      post "/org/#{organization.permalink}/servers/#{server.permalink}/credentials",
           params: { credential: { type: "API", name: "Test", hold: false } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include("read-only access")
    end

    it "blocks updating organization settings" do
      patch "/org/#{organization.permalink}/settings",
            params: { organization: { name: "Renamed Org" } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to match(/read-only access|do not have permission/i)
    end
  end
end
