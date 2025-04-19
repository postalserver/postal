# frozen_string_literal: true

require "rails_helper"

describe "Legacy API - Servers API" do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server, type: "API") }
  let(:headers) { { "X-Server-API-Key" => credential.key } }

  context "POST /api/v1/servers/list" do
    before do
      # Create additional servers for testing
      create_list(:server, 2, organization: organization)
    end

    it "returns a list of servers for the organization" do
      post "/api/v1/servers/list", params: { params: {}.to_json }, headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("success")
      expect(json["data"]["servers"]).to be_an(Array)
      expect(json["data"]["servers"].length).to eq(3) # Original + 2 created in before block
      
      # Check if server properties are properly included
      server_data = json["data"]["servers"].find { |s| s["uuid"] == server.uuid }
      expect(server_data).to be_present
      expect(server_data["name"]).to eq(server.name)
      expect(server_data["permalink"]).to eq(server.permalink)
    end
  end

  context "POST /api/v1/servers/show" do
    let(:params) do
      {
        server_id: server.uuid
      }
    end

    it "returns detailed information about a server" do
      post "/api/v1/servers/show", params: { params: params.to_json }, headers: headers
      expect(response.status).to eq(200)
      
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("success")
      expect(json["data"]["server"]).to be_a(Hash)
      expect(json["data"]["server"]["uuid"]).to eq(server.uuid)
      expect(json["data"]["server"]["name"]).to eq(server.name)
      expect(json["data"]["server"]["organization"]["name"]).to eq(organization.name)
    end

    it "returns server with domains when include_domains is true" do
      # Create a domain for the server
      domain = create(:domain, server: server)
      
      params[:include_domains] = true
      post "/api/v1/servers/show", params: { params: params.to_json }, headers: headers
      
      json = JSON.parse(response.body)
      expect(json["data"]["server"]["domains"]).to be_an(Array)
      expect(json["data"]["server"]["domains"].length).to eq(1)
      expect(json["data"]["server"]["domains"][0]["uuid"]).to eq(domain.uuid)
    end

    it "returns error if server_id is missing" do
      params.delete(:server_id)
      post "/api/v1/servers/show", params: { params: params.to_json }, headers: headers
      
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("parameter-error")
    end

    it "returns error if server doesn't exist" do
      params[:server_id] = "non-existent-uuid"
      post "/api/v1/servers/show", params: { params: params.to_json }, headers: headers
      
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("error")
      expect(json["data"]["code"]).to eq("InvalidServer")
    end
  end
end