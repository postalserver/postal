# frozen_string_literal: true

require "rails_helper"

module SMTPServer

  describe Client do
    let(:ip_address) { "1.2.3.4" }
    subject(:client) { described_class.new(ip_address) }

    describe "HELO" do
      it "returns the hostname" do
        expect(client.state).to eq :welcome
        expect(client.handle("HELO: test.example.com")).to eq "250 #{Postal::Config.postal.smtp_hostname}"
        expect(client.state).to eq :welcomed
      end
    end

    describe "EHLO" do
      it "returns the capabilities" do
        expect(client.handle("EHLO test.example.com")).to eq ["250-My capabilities are",
                                                              "250 AUTH CRAM-MD5 PLAIN LOGIN",]
      end

      context "when TLS is enabled" do
        it "returns capabilities include starttls" do
          allow(Postal::Config.smtp_server).to receive(:tls_enabled?).and_return(true)
          expect(client.handle("EHLO test.example.com")).to eq ["250-My capabilities are",
                                                                "250-STARTTLS",
                                                                "250 AUTH CRAM-MD5 PLAIN LOGIN",]
        end
      end
    end
  end

end
