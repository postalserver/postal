# frozen_string_literal: true

require "rails_helper"

module SMTPServer

  describe Client do
    let(:ip_address) { "1.2.3.4" }

    subject(:client) { described_class.new(ip_address) }

    describe "RCPT TO for a TLS report" do
      let(:domain) { create(:domain, name: "example.com") }

      before do
        domain
        client.handle("HELO test.example.com")
        client.handle("MAIL FROM: reporter@example.net")
      end

      it "accepts a report for a domain which is hosted here" do
        expect(client.handle("RCPT TO: tlsrpt@example.com")).to eq "250 2.1.5 OK"
        expect(client.recipients).to eq [[:tls_report, "tlsrpt@example.com", domain]]
        expect(client.state).to eq :rcpt_to_received
      end

      it "records the domain the report was submitted for" do
        client.handle("RCPT TO: tlsrpt@example.com")
        expect(client.recipients.first.last).to eq domain
      end

      it "accepts a report when the address carries a tag" do
        expect(client.handle("RCPT TO: tlsrpt+20260918@example.com")).to eq "250 2.1.5 OK"
        expect(client.recipients.first).to eq [:tls_report, "tlsrpt+20260918@example.com", domain]
      end

      it "is not sensitive to the case of the local part" do
        expect(client.handle("RCPT TO: TLSRPT@example.com")).to eq "250 2.1.5 OK"
      end

      it "does not treat another local part on the same domain as a report" do
        expect(client.handle("RCPT TO: someone@example.com")).to_not include "2.1.5"
        expect(client.recipients).to be_empty
      end

      it "does not treat a report address on a domain which is not hosted here as a report" do
        expect(client.handle("RCPT TO: tlsrpt@not-hosted.example")).to_not include "2.1.5"
        expect(client.recipients).to be_empty
      end
    end

    describe "when a different local part is configured" do
      before do
        create(:domain, name: "example.com")
        allow(Postal::Config.dns).to receive(:tls_rpt_local_part).and_return("reports")
        client.handle("HELO test.example.com")
        client.handle("MAIL FROM: reporter@example.net")
      end

      it "accepts the configured local part" do
        expect(client.handle("RCPT TO: reports@example.com")).to eq "250 2.1.5 OK"
      end

      it "does not accept tlsrpt, which is then an ordinary address" do
        expect(client.handle("RCPT TO: tlsrpt@example.com")).to_not include "2.1.5"
      end
    end

    describe "when ingestion is switched off" do
      before do
        create(:domain, name: "example.com")
        allow(Postal::Config.dns).to receive(:tls_rpt_local_part).and_return("")
        client.handle("HELO test.example.com")
        client.handle("MAIL FROM: reporter@example.net")
      end

      it "does not treat any address as a report" do
        expect(client.handle("RCPT TO: tlsrpt@example.com")).to_not include "2.1.5"
      end
    end
  end

end
