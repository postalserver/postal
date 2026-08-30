# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Control API v2 organizations", type: :request do
  let(:platform_key) { ControlAPIKey.issue!(name: "Platform", scopes: ["platform:admin"]).last }
  let(:headers) { { "Authorization" => "Bearer #{platform_key}", "Content-Type" => "application/json" } }

  it "creates an organization, owner, and administrator membership" do
    post "/api/v2/organizations", params: {
      name: "Example NGO", permalink: "example-ngo", time_zone: "Asia/Kolkata", plan_code: "starter",
      owner: { email_address: "admin@example.org", first_name: "Example", last_name: "Admin" }
    }.to_json, headers: headers

    expect(response).to have_http_status(:created)
    organization = Organization.find_by!(permalink: "example-ngo")
    expect(organization.owner.email_address).to eq("admin@example.org")
    expect(organization.organization_users.find_by!(user: organization.owner)).to have_attributes(admin: true, all_servers: true)
    expect(AuditEvent.last.action).to eq("organization.created")
  end

  it "does not disclose another organization to an organization-scoped key" do
    own = create(:organization)
    other = create(:organization)
    token = ControlAPIKey.issue!(name: "Tenant", organization: own, scopes: ["organizations:read"]).last

    get "/api/v2/organizations/#{other.uuid}", headers: { "Authorization" => "Bearer #{token}" }

    expect(response).to have_http_status(:not_found)
  end

  it "replays a matching idempotent create and rejects a changed payload" do
    payload = {
      name: "Idempotent NGO", permalink: "idempotent-ngo", time_zone: "UTC",
      owner: { email_address: "idempotent@example.org", first_name: "Idempotent", last_name: "Owner" }
    }
    idempotency_headers = headers.merge("Idempotency-Key" => "organization-create-1")

    post "/api/v2/organizations", params: payload.to_json, headers: idempotency_headers
    first_response = JSON.parse(response.body)

    post "/api/v2/organizations", params: payload.to_json, headers: idempotency_headers
    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body).dig("data", "uuid")).to eq(first_response.dig("data", "uuid"))
    expect(Organization.where(permalink: "idempotent-ngo").count).to eq(1)

    post "/api/v2/organizations", params: payload.merge(name: "Changed").to_json, headers: idempotency_headers
    expect(response).to have_http_status(:conflict)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("idempotency_conflict")
  end

  it "does not create an owner when organization validation fails" do
    create(:organization, permalink: "already-taken")
    payload = {
      name: "Rejected NGO", permalink: "already-taken", time_zone: "UTC",
      owner: { email_address: "orphan@example.org", first_name: "Orphan", last_name: "Owner" }
    }

    expect do
      post "/api/v2/organizations", params: payload.to_json, headers: headers
    end.not_to change(User.where(email_address: "orphan@example.org"), :count)

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "enforces a unique email index for organization owners" do
    email_index = ActiveRecord::Base.connection.indexes(:users).find { |index| index.name == "index_users_on_email_address" }

    expect(email_index.unique).to be(true)
  end

  it "allows distinct owner email addresses with the same legacy index prefix" do
    User.create!(email_address: "support@one.example", first_name: "One", last_name: "Support", password: "a-secure-password")

    expect do
      User.create!(email_address: "support@two.example", first_name: "Two", last_name: "Support", password: "a-secure-password")
    end.not_to raise_error
  end

  it "does not execute a request while its idempotency key is pending" do
    control_key = ControlAPIKey.find_by!(token_digest: Digest::SHA256.hexdigest(platform_key))
    control_key.idempotency_records.create!(key: "organization-pending-1", request_method: "POST", request_path: "/api/v2/organizations", payload_digest: "pending")

    post "/api/v2/organizations", params: {
      name: "Pending NGO", permalink: "pending-ngo", time_zone: "UTC",
      owner: { email_address: "pending@example.org", first_name: "Pending", last_name: "Owner" }
    }.to_json, headers: headers.merge("Idempotency-Key" => "organization-pending-1")

    expect(response).to have_http_status(:conflict)
    expect(Organization.find_by(permalink: "pending-ngo")).to be_nil
  end
end
