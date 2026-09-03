# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Control API v2 collection lifecycle", type: :request do
  let(:token) { ControlAPIKey.issue!(name: "Platform", scopes: ["platform:admin"]).last }
  let(:headers) { { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" } }

  def expect_status(status)
    expect(response).to have_http_status(status)
  end

  def data_uuid
    JSON.parse(response.body).fetch("data").fetch("uuid")
  end

  it "executes every request in the Control API v2 Postman collection" do
    suffix = SecureRandom.hex(6)

    get "/api/v2/health", headers: headers
    expect_status(:ok)

    post "/api/v2/organizations", params: {
      name: "Collection Test #{suffix}", permalink: "collection-test-#{suffix}", time_zone: "UTC",
      owner: { email_address: "collection-#{suffix}@example.test", first_name: "Collection", last_name: "Test" }
    }.to_json, headers: headers
    expect_status(:created)
    organization_uuid = data_uuid
    organization_path = "/api/v2/organizations/#{organization_uuid}"

    get "/api/v2/organizations", headers: headers
    expect_status(:ok)
    get organization_path, headers: headers
    expect_status(:ok)
    patch organization_path, params: { monthly_outbound_limit: 1_000, quota_warning_percent: 80, quota_action: "monitor" }.to_json, headers: headers
    expect_status(:ok)
    post "#{organization_path}/suspend", params: { reason: "collection test" }.to_json, headers: headers
    expect_status(:ok)
    post "#{organization_path}/unsuspend", headers: headers
    expect_status(:ok)

    post "#{organization_path}/servers", params: { name: "Collection Server", permalink: "collection-server-#{suffix}", mode: "Live", send_limit: 100 }.to_json, headers: headers
    expect_status(:created)
    server_uuid = data_uuid
    server_path = "#{organization_path}/servers/#{server_uuid}"

    get "#{organization_path}/servers", headers: headers
    expect_status(:ok)
    get server_path, headers: headers
    expect_status(:ok)
    patch server_path, params: { send_limit: 200 }.to_json, headers: headers
    expect_status(:ok)
    post "#{server_path}/suspend", params: { reason: "collection test" }.to_json, headers: headers
    expect_status(:ok)
    post "#{server_path}/unsuspend", headers: headers
    expect_status(:ok)

    post "#{server_path}/domains", params: { name: "#{suffix}.example.test" }.to_json, headers: headers
    expect_status(:created)
    domain_uuid = data_uuid
    domain_path = "#{server_path}/domains/#{domain_uuid}"
    get "#{server_path}/domains", headers: headers
    expect_status(:ok)
    get domain_path, headers: headers
    expect_status(:ok)
    allow_any_instance_of(Domain).to receive(:verify_with_dns)
    post "#{domain_path}/verify", headers: headers
    expect_status(:ok)
    allow_any_instance_of(Domain).to receive(:check_dns)
    post "#{domain_path}/check-dns", headers: headers
    expect_status(:ok)

    post "#{server_path}/credentials", params: { name: "Collection credential", type: "API" }.to_json, headers: headers
    expect_status(:created)
    credential_uuid = data_uuid
    get "#{server_path}/credentials", headers: headers
    expect_status(:ok)
    post "#{server_path}/credentials/#{credential_uuid}/rotate", headers: headers
    expect_status(:created)
    credential_uuid = data_uuid

    allow(Postal::HTTP::AddressGuard).to receive(:safe_connect_address).with("hooks.example.test").and_return("203.0.113.10")
    post "#{server_path}/webhooks", params: { name: "Collection webhook", url: "https://hooks.example.test/postal" }.to_json, headers: headers
    expect_status(:created)
    webhook_uuid = data_uuid
    webhook_path = "#{server_path}/webhooks/#{webhook_uuid}"
    get "#{server_path}/webhooks", headers: headers
    expect_status(:ok)
    get webhook_path, headers: headers
    expect_status(:ok)
    patch webhook_path, params: { name: "Updated collection webhook" }.to_json, headers: headers
    expect_status(:ok)

    get "#{organization_path}/usage?granularity=daily", headers: headers
    expect_status(:ok)
    get "#{server_path}/usage?granularity=hourly", headers: headers
    expect_status(:ok)
    get "#{server_path}/health", headers: headers
    expect_status(:ok)

    delete "#{server_path}/credentials/#{credential_uuid}", headers: headers
    expect_status(:no_content)
    delete webhook_path, headers: headers
    expect_status(:no_content)
    delete domain_path, headers: headers
    expect_status(:no_content)
    delete server_path, headers: headers
    expect_status(:no_content)
    delete organization_path, headers: headers
    expect_status(:no_content)
  end
end
