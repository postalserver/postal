# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Legacy HTTP send quota enforcement", type: :request do
  let(:organization) { create(:organization, monthly_outbound_limit: 1, quota_action: "hold") }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server, type: "API") }
  let(:domain) { create(:domain, owner: server) }
  let(:decision) { ControlPlane::OutboundQuota::Decision.new(action: :hold, limit: 1, used: 2, requested: 1) }

  it "uses the shared organization quota gate and holds mail when it says hold" do
    expect(ControlPlane::OutboundQuota).to receive(:reserve!).with(server, count: 1).and_return(decision)

    post "/api/v1/send/message", headers: { "X-Server-API-Key" => credential.key, "Content-Type" => "application/json" },
                                 params: { to: ["recipient@example.net"], from: "sender@#{domain.name}", plain_body: "test" }.to_json

    expect(response).to have_http_status(:ok)
    message_id = JSON.parse(response.body).dig("data", "messages", "recipient@example.net", "id")
    expect(server.message(message_id)).to be_held
    expect(QueuedMessage.where(server: server)).to be_empty
  end
end
