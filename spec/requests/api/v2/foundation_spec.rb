# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Control API v2 foundation", type: :request do
  let(:key) { ControlAPIKey.issue!(name: "Control panel", scopes: ["usage:read"]) }

  it "requires a Bearer token and returns the v2 error envelope" do
    get "/api/v2/health"

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)).to include("data" => nil, "meta" => {}, "error" => include("code" => "unauthorized"))
  end

  it "authenticates a Bearer token and returns request metadata" do
    _control_key, token = key
    get "/api/v2/health", headers: { "Authorization" => "Bearer #{token}" }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to include("data" => { "status" => "ok" }, "error" => nil)
    expect(response.headers["X-Request-Id"]).to be_present
  end

  it "does not accept a token in a query parameter" do
    _control_key, token = key
    get "/api/v2/health?token=#{token}"

    expect(response).to have_http_status(:unauthorized)
  end
end
