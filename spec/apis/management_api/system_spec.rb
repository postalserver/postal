# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Management API - System", type: :request do
  describe "GET /api/v2/management/system/health" do
    it "returns healthy status without authentication" do
      get "/api/v2/management/system/health"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("healthy")
      expect(json["version"]).to be_present
    end
  end

  describe "GET /api/v2/management/system/status" do
    context "when not authenticated" do
      it "returns 401" do
        get "/api/v2/management/system/status"

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("error")
        expect(json["error"]["code"]).to eq("AuthenticationRequired")
      end
    end

    context "when authenticated" do
      let(:api_key) { create(:management_api_key, :super_admin) }

      it "returns system status" do
        get "/api/v2/management/system/status",
            headers: { "X-Management-API-Key" => api_key.key }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("success")
        expect(json["data"]["version"]).to be_present
        expect(json["data"]["authenticated_as"]["uuid"]).to eq(api_key.uuid)
      end

      it "supports Bearer token authentication" do
        get "/api/v2/management/system/status",
            headers: { "Authorization" => "Bearer #{api_key.key}" }

        expect(response).to have_http_status(:ok)
      end
    end

    context "with invalid API key" do
      it "returns 401" do
        get "/api/v2/management/system/status",
            headers: { "X-Management-API-Key" => "invalid_key" }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("InvalidApiKey")
      end
    end
  end

  describe "GET /api/v2/management/system/stats" do
    let(:api_key) { create(:management_api_key, :super_admin) }

    context "with super admin key" do
      it "returns system statistics" do
        get "/api/v2/management/system/stats",
            headers: { "X-Management-API-Key" => api_key.key }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("success")
        expect(json["data"]).to have_key("organizations")
        expect(json["data"]).to have_key("servers")
        expect(json["data"]).to have_key("users")
      end
    end

    context "with organization-scoped key" do
      let(:org_key) { create(:management_api_key, :organization_scoped) }

      it "returns 403" do
        get "/api/v2/management/system/stats",
            headers: { "X-Management-API-Key" => org_key.key }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
