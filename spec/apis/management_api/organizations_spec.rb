# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Management API - Organizations", type: :request do
  let(:api_key) { create(:management_api_key, :super_admin) }
  let(:headers) { { "X-Management-API-Key" => api_key.key } }

  describe "GET /api/v2/management/organizations" do
    let!(:organization) { create(:organization) }

    it "returns list of organizations" do
      get "/api/v2/management/organizations", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("success")
      expect(json["data"]).to be_an(Array)
      expect(json["data"].first["permalink"]).to eq(organization.permalink)
    end

    it "supports pagination" do
      get "/api/v2/management/organizations", headers: headers, params: { page: 1, per_page: 10 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["meta"]).to include("page", "per_page", "total", "total_pages")
    end

    context "with organization-scoped key" do
      let(:org_key) { create(:management_api_key, :organization_scoped, organization: organization) }

      it "only returns the scoped organization" do
        create(:organization) # Another org
        get "/api/v2/management/organizations",
            headers: { "X-Management-API-Key" => org_key.key }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"].length).to eq(1)
        expect(json["data"].first["permalink"]).to eq(organization.permalink)
      end
    end
  end

  describe "GET /api/v2/management/organizations/:permalink" do
    let!(:organization) { create(:organization) }

    it "returns organization details" do
      get "/api/v2/management/organizations/#{organization.permalink}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("success")
      expect(json["data"]["name"]).to eq(organization.name)
      expect(json["data"]["owner"]).to be_present
      expect(json["data"]["stats"]).to be_present
    end

    it "returns 404 for non-existent organization" do
      get "/api/v2/management/organizations/nonexistent", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v2/management/organizations" do
    let(:owner) { create(:user) }

    it "creates a new organization" do
      post "/api/v2/management/organizations",
           headers: headers,
           params: {
             name: "New Organization",
             permalink: "new-org",
             time_zone: "UTC",
             owner_email: owner.email_address
           }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("success")
      expect(json["data"]["name"]).to eq("New Organization")
      expect(json["data"]["permalink"]).to eq("new-org")
    end

    it "returns error when owner not found" do
      post "/api/v2/management/organizations",
           headers: headers,
           params: {
             name: "New Organization",
             owner_email: "nonexistent@example.com"
           }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("OwnerNotFound")
    end

    it "returns error when owner_email not provided" do
      post "/api/v2/management/organizations",
           headers: headers,
           params: { name: "New Organization" }

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("OwnerRequired")
    end

    context "with organization-scoped key" do
      let(:org_key) { create(:management_api_key, :organization_scoped) }

      it "returns 403" do
        post "/api/v2/management/organizations",
             headers: { "X-Management-API-Key" => org_key.key },
             params: { name: "Test" }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /api/v2/management/organizations/:permalink" do
    let!(:organization) { create(:organization) }

    it "updates the organization" do
      patch "/api/v2/management/organizations/#{organization.permalink}",
            headers: headers,
            params: { name: "Updated Name" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["name"]).to eq("Updated Name")
      expect(organization.reload.name).to eq("Updated Name")
    end
  end

  describe "DELETE /api/v2/management/organizations/:permalink" do
    let!(:organization) { create(:organization) }

    it "soft deletes the organization" do
      delete "/api/v2/management/organizations/#{organization.permalink}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["deleted"]).to be true
      expect(organization.reload.deleted_at).to be_present
    end
  end

  describe "POST /api/v2/management/organizations/:permalink/suspend" do
    let!(:organization) { create(:organization) }

    it "suspends the organization" do
      post "/api/v2/management/organizations/#{organization.permalink}/suspend",
           headers: headers,
           params: { reason: "Test suspension" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["suspended"]).to be true
      expect(organization.reload.suspended?).to be true
    end
  end

  describe "POST /api/v2/management/organizations/:permalink/unsuspend" do
    let!(:organization) { create(:organization, :suspended) }

    it "unsuspends the organization" do
      post "/api/v2/management/organizations/#{organization.permalink}/unsuspend",
           headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["suspended"]).to be false
      expect(organization.reload.suspended?).to be false
    end
  end
end
