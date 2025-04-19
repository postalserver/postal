# frozen_string_literal: true

require "rails_helper"

describe "Legacy API - Domains API" do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server, type: "API") }
  let(:headers) { { "X-Server-API-Key" => credential.key } }

  context "POST /api/v1/domains/create" do
    let(:domain_name) { "test-#{SecureRandom.alphanumeric(6)}.example.com" }
    let(:params) do
      {
        name: domain_name
      }
    end

    it "creates a new domain" do
      post "/api/v1/domains/create", params: { params: params.to_json }, headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("success")
      expect(json["data"]["domain"]["name"]).to eq(domain_name)
      expect(json["data"]["domain"]["verification_method"]).to eq("DNS")
      
      # Verify the domain was created in the database
      domain = server.domains.find_by(name: domain_name)
      expect(domain).to be_present
    end

    it "returns error if name is missing" do
      params.delete(:name)
      post "/api/v1/domains/create", params: { params: params.to_json }, headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("parameter-error")
    end
  end

  context "POST /api/v1/domains/verify" do
    let!(:domain) { create(:domain, server: server, verification_method: "DNS") }
    let(:params) do
      {
        domain_id: domain.uuid
      }
    end

    it "attempts to verify a domain" do
      # Mock the DNS verification to return false
      allow_any_instance_of(Domain).to receive(:verify_with_dns).and_return(false)
      
      post "/api/v1/domains/verify", params: { params: params.to_json }, headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("error")
      expect(json["data"]["code"]).to eq("VerificationFailed")
    end

    it "succeeds when verification passes" do
      # Mock the DNS verification to return true
      allow_any_instance_of(Domain).to receive(:verify_with_dns).and_return(true)
      
      post "/api/v1/domains/verify", params: { params: params.to_json }, headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("success")
      expect(json["data"]["domain"]["verified"]).to eq(true)
    end
  end
  
  context "POST /api/v1/domains/dns_records" do
    let!(:domain) { create(:domain, server: server, verification_method: "DNS") }
    let(:params) do
      {
        domain_id: domain.uuid
      }
    end

    before do
      # Configure DNS settings for testing
      allow(Postal::Config.dns).to receive(:spf_include).and_return("spf.example.com")
      allow(Postal::Config.dns).to receive(:dkim_identifier).and_return("postal")
      allow(Postal::Config.dns).to receive(:custom_return_path_prefix).and_return("rp")
      allow(Postal::Config.dns).to receive(:return_path).and_return("return.example.com")
      allow(Postal::Config.dns).to receive(:mx_records).and_return(["mx.example.com"])
      allow(Postal::Config.dns).to receive(:track_domain).and_return("track.example.com")
      allow(Postal::Config.dns).to receive(:domain_verify_prefix).and_return("postal-verify")
    end

    it "returns DNS records for a domain" do
      post "/api/v1/domains/dns_records", params: { params: params.to_json }, headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("success")
      expect(json["data"]["domain"]["uuid"]).to eq(domain.uuid)
      expect(json["data"]["domain"]["name"]).to eq(domain.name)
      expect(json["data"]["dns_records"]).to be_an(Array)
      
      # Check if all required record types are present
      record_types = json["data"]["dns_records"].map { |r| r["purpose"] }
      expect(record_types).to include("spf")
      expect(record_types).to include("dkim")
      expect(record_types).to include("return_path")
      
      # For verified domains, there should be no verification record
      if domain.verified?
        expect(record_types).not_to include("verification")
      else
        expect(record_types).to include("verification")
      end
    end

    it "returns error if domain_id is missing" do
      params.delete(:domain_id)
      post "/api/v1/domains/dns_records", params: { params: params.to_json }, headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("parameter-error")
    end
  end
end