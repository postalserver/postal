# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Control API v2 resources", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:token) { ControlAPIKey.issue!(name: "Platform", scopes: ["platform:admin"]).last }
  let(:headers) { { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" } }
  let(:base_path) { "/api/v2/organizations/#{organization.uuid}/servers/#{server.uuid}" }

  it "serializes required DNS records without the DKIM private key" do
    post "#{base_path}/domains", params: { name: "example.org" }.to_json, headers: headers

    expect(response).to have_http_status(:created)
    data = JSON.parse(response.body).fetch("data")
    expect(data.fetch("dns_records").fetch("dkim").fetch("value")).to include("v=DKIM1")
    expect(response.body).not_to include("dkim_private_key")
    expect(response.body).not_to include(Domain.last.dkim_private_key)
  end

  it "checks the verification TXT record before reporting DNS status" do
    domain = create(:domain, owner: server, verification_method: "DNS", verified_at: nil)
    expect_any_instance_of(Domain).to receive(:verify_with_dns)
    allow_any_instance_of(Domain).to receive(:check_dns)
    allow_any_instance_of(Domain).to receive(:resolver).and_return(instance_double(DNSResolver, txt: []))

    post "#{base_path}/domains/#{domain.uuid}/check-dns", headers: headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig("data", "dns_status", "dmarc", "status")).to eq("Missing")
  end

  it "replays an idempotent domain create" do
    idempotency_headers = headers.merge("Idempotency-Key" => "domain-create-1")
    payload = { name: "idempotent.example.org" }.to_json

    post "#{base_path}/domains", params: payload, headers: idempotency_headers
    first_uuid = JSON.parse(response.body).dig("data", "uuid")

    post "#{base_path}/domains", params: payload, headers: idempotency_headers

    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body).dig("data", "uuid")).to eq(first_uuid)
    expect(server.domains.where(name: "idempotent.example.org").count).to eq(1)
  end

  it "returns a credential secret only when it is created" do
    post "#{base_path}/credentials", params: { name: "SaaS API", type: "API" }.to_json, headers: headers

    expect(response).to have_http_status(:created)
    created = JSON.parse(response.body).fetch("data")
    expect(created.fetch("key")).to be_present
    expect(created.fetch("key_hint")).to end_with(created.fetch("key").last(4))

    get "#{base_path}/credentials", headers: headers

    listed = JSON.parse(response.body).fetch("data").first
    expect(listed).not_to have_key("key")
    expect(listed.fetch("key_hint")).to end_with(created.fetch("key").last(4))
  end

  it "replays an idempotent credential revocation after the credential is gone" do
    credential = create(:credential, server: server, type: "API")
    idempotency_headers = headers.merge("Idempotency-Key" => "credential-delete-#{credential.uuid}")

    delete "#{base_path}/credentials/#{credential.uuid}", headers: idempotency_headers
    expect(response).to have_http_status(:no_content)

    delete "#{base_path}/credentials/#{credential.uuid}", headers: idempotency_headers

    expect(response).to have_http_status(:no_content)
  end

  it "rotates a credential once and audits only masked metadata" do
    credential = create(:credential, server: server, type: "API")
    old_key = credential.key

    post "#{base_path}/credentials/#{credential.uuid}/rotate", headers: headers.merge("Idempotency-Key" => "rotate-#{credential.uuid}")

    expect(response).to have_http_status(:created)
    replacement = JSON.parse(response.body).fetch("data")
    expect(replacement.fetch("key")).not_to eq(old_key)
    expect(server.credentials.where(uuid: credential.uuid)).to be_empty
    expect(AuditEvent.last.after_metadata.to_s).not_to include(replacement.fetch("key"))
  end

  it "suspends and reactivates a server without exposing a sequential id" do
    post "#{base_path}/suspend", params: { reason: "abuse review" }.to_json, headers: headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig("data", "status")).to eq("suspended")
    expect(server.reload.actual_suspension_reason).to eq("abuse review")

    post "#{base_path}/unsuspend", headers: headers

    expect(response).to have_http_status(:ok)
    data = JSON.parse(response.body).fetch("data")
    expect(data.fetch("status")).to eq("live")
    expect(data).not_to have_key("id")
  end

  it "uses the member UUID for server health and usage" do
    report = instance_double(ControlPlane::UsageReport,
                             call: { totals: { outgoing: 0, bounces: 0 }, series: [], rolling: {} })
    expect(ControlPlane::UsageReport).to receive(:new).with(hash_including(servers: [server])).and_return(report)

    get "#{base_path}/usage", headers: headers

    expect(response).to have_http_status(:ok)

    get "#{base_path}/health", headers: headers

    expect(response).to have_http_status(:ok)
  end

  it "rejects rotation of SMTP-IP credentials" do
    credential = create(:credential, server: server, type: "SMTP-IP", key: "203.0.113.5")

    post "#{base_path}/credentials/#{credential.uuid}/rotate", headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("credential_rotation_unsupported")
    expect(server.credentials.find_by!(uuid: credential.uuid)).to be_present
  end

  it "rejects local webhook destinations before saving a webhook" do
    post "#{base_path}/webhooks", params: { name: "Local", url: "https://127.0.0.1/hook" }.to_json, headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("unsafe_webhook_url")
    expect(server.webhooks).to be_empty
  end

  it "replays an idempotent webhook create without creating a duplicate" do
    allow(Postal::HTTP::AddressGuard).to receive(:safe_connect_address).with("hooks.example.net").and_return("203.0.113.10")
    idempotency_headers = headers.merge("Idempotency-Key" => "webhook-create-1")
    payload = { name: "Events", url: "https://hooks.example.net/postal" }.to_json

    post "#{base_path}/webhooks", params: payload, headers: idempotency_headers
    first_uuid = JSON.parse(response.body).dig("data", "uuid")

    post "#{base_path}/webhooks", params: payload, headers: idempotency_headers

    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body).dig("data", "uuid")).to eq(first_uuid)
    expect(server.webhooks.where(name: "Events").count).to eq(1)
  end

  it "defaults a webhook with no event selection to all events" do
    allow(Postal::HTTP::AddressGuard).to receive(:safe_connect_address).with("hooks.example.net").and_return("203.0.113.10")

    post "#{base_path}/webhooks", params: { name: "All events", url: "https://hooks.example.net/postal" }.to_json, headers: headers

    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body).dig("data", "all_events")).to be(true)
  end

  it "enables incoming mail by creating an address endpoint and route" do
    domain = create(:domain, owner: server, verified_at: Time.current, incoming: false)

    post "#{base_path}/incoming-routes", params: { domain_uuid: domain.uuid, name: "hello", destination: { type: "address", address: "inbox@example.net" } }.to_json, headers: headers

    expect(response).to have_http_status(:created)
    route = server.routes.last
    expect(route).to have_attributes(name: "hello", domain: domain, mode: "Endpoint")
    expect(route.endpoint).to be_a(AddressEndpoint)
    expect(route.endpoint.address).to eq("inbox@example.net")
    expect(domain.reload.incoming).to be(true)
  end

  it "does not enable incoming mail for an unverified domain" do
    domain = create(:domain, owner: server, verified_at: nil)

    post "#{base_path}/incoming-routes", params: { domain_uuid: domain.uuid, name: "hello", destination: { type: "address", address: "inbox@example.net" } }.to_json, headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("domain_not_verified")
    expect(server.routes).to be_empty
  end

  it "returns a validation error when the webhook host is unreachable" do
    allow(Postal::HTTP::AddressGuard).to receive(:safe_connect_address).and_raise(SocketError)

    post "#{base_path}/webhooks", params: { name: "Unreachable", url: "https://hooks.example.net/postal" }.to_json, headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("unsafe_webhook_url")
  end
end
