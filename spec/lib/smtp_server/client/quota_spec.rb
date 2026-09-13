# frozen_string_literal: true

require "rails_helper"

module SMTPServer

  RSpec.describe Client do
    let(:organization) { create(:organization, monthly_outbound_limit: 1, quota_action: "hold") }
    let(:server) { create(:server, organization: organization) }
    let(:credential) { create(:credential, server: server, type: "SMTP") }
    let(:domain) { create(:domain, owner: server) }
    let(:decision) { ControlPlane::OutboundQuota::Decision.new(action: :hold, limit: 1, used: 2, requested: 1) }

    it "uses the same shared quota gate for authenticated SMTP submission" do
      client = described_class.new("1.2.3.4")
      client.handle("HELO test.example.com")
      client.handle("AUTH PLAIN #{credential.to_smtp_plain}")
      client.handle("MAIL FROM: sender@#{domain.name}")
      client.handle("RCPT TO: recipient@example.net")
      client.handle("DATA")
      client.handle("From: sender@#{domain.name}")
      client.handle("To: recipient@example.net")
      client.handle("")
      client.handle("test")
      client.handle("\r")

      expect(ControlPlane::OutboundQuota).to receive(:reserve!).with(server, count: 1).and_return(decision)
      expect(client.handle(".\r")).to eq("250 OK")
      expect(QueuedMessage.where(server: server)).to be_empty
    end
  end

end
