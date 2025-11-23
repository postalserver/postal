# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Management API Domains", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:api_key) { create(:management_api_key, organization: organization) }
  let(:headers) { { "X-Management-API-Key" => api_key.key } }

  describe "POST /api/v2/management/servers/:server_id/domains" do
    context "when creating a domain without specifying verification_method" do
      it "creates a domain with DNS verification method and generates verification token" do
        post "/api/v2/management/servers/#{server.uuid}/domains",
             params: { name: "example.com" }.to_json,
             headers: headers.merge("Content-Type" => "application/json")

        expect(response).to have_http_status(:created)

        json = JSON.parse(response.body)
        expect(json["status"]).to eq("success")
        expect(json["data"]["name"]).to eq("example.com")
        expect(json["data"]["verification_method"]).to eq("DNS")
        expect(json["data"]["verification_token"]).to be_present
        expect(json["data"]["verification_token"]).to match(/\A[A-Za-z0-9]{32}\z/)
        expect(json["data"]["dns_verification_string"]).to be_present
        expect(json["data"]["dkim_identifier"]).to be_present
        expect(json["data"]["dkim_record"]).to be_present

        # Verify the domain was actually created correctly in the database
        domain = Domain.find_by(name: "example.com")
        expect(domain).to be_present
        expect(domain.verification_method).to eq("DNS")
        expect(domain.verification_token).to be_present
        expect(domain.verification_token).to match(/\A[A-Za-z0-9]{32}\z/)
      end
    end

    context "when creating a domain with Email verification method" do
      it "creates a domain with Email verification method and generates numeric token" do
        post "/api/v2/management/servers/#{server.uuid}/domains",
             params: { name: "example.com", verification_method: "Email" }.to_json,
             headers: headers.merge("Content-Type" => "application/json")

        expect(response).to have_http_status(:created)

        json = JSON.parse(response.body)
        expect(json["status"]).to eq("success")
        expect(json["data"]["verification_method"]).to eq("Email")
        expect(json["data"]["verification_token"]).to be_present
        expect(json["data"]["verification_token"]).to match(/\A\d{6}\z/)

        # Verify the domain was actually created correctly in the database
        domain = Domain.find_by(name: "example.com")
        expect(domain).to be_present
        expect(domain.verification_method).to eq("Email")
        expect(domain.verification_token).to match(/\A\d{6}\z/)
      end
    end
  end

  describe "POST /api/v2/management/servers/:server_id/domains/:id/verify" do
    let(:domain) { create(:domain, :unverified, server: server, owner: server, verification_method: "DNS") }

    context "when DNS verification succeeds" do
      before do
        # Mock the DNS lookup to return the verification string
        allow_any_instance_of(Domain).to receive(:verify_with_dns).and_return(true)
      end

      it "verifies the domain successfully" do
        post "/api/v2/management/servers/#{server.uuid}/domains/#{domain.uuid}/verify",
             headers: headers.merge("Content-Type" => "application/json")

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("success")
        expect(json["data"]["verified"]).to be true
        expect(json["data"]["verified_at"]).to be_present
      end
    end

    context "when DNS verification fails" do
      before do
        # Mock the DNS lookup to fail (no matching TXT record)
        allow_any_instance_of(Domain).to receive(:verify_with_dns).and_return(false)
      end

      it "returns a verification failed error" do
        post "/api/v2/management/servers/#{server.uuid}/domains/#{domain.uuid}/verify",
             headers: headers.merge("Content-Type" => "application/json")

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("error")
        expect(json["error"]["code"]).to eq("VerificationFailed")
        expect(json["error"]["message"]).to include("DNS verification failed")
      end
    end
  end
end
