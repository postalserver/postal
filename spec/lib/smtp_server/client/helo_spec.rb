# frozen_string_literal: true

require "rails_helper"

module SMTPServer

  describe Client do
    let(:ip_address) { "1.2.3.4" }
    subject(:client) { described_class.new(ip_address) }

    describe "HELO" do
      it "returns the hostname" do
        expect(client.state).to eq :welcome
        expect(client.handle("HELO: test.example.com")).to eq "250 2.0.0 #{Postal::Config.postal.smtp_hostname}"
        expect(client.state).to eq :welcomed
      end
    end

    describe "EHLO" do
      let(:size_capability) { "250-SIZE #{Postal::Config.smtp_server.max_message_size.megabytes.to_i}" }
      let(:body_capabilities) { %w[250-8BITMIME 250-SMTPUTF8 250-PIPELINING] }

      it "returns the capabilities" do
        expect(client.handle("EHLO test.example.com")).to eq ["250-My capabilities are",
                                                              size_capability,
                                                              *body_capabilities,
                                                              "250 AUTH CRAM-MD5 PLAIN LOGIN",]
      end

      it "advertises the configured maximum message size" do
        allow(Postal::Config.smtp_server).to receive(:max_message_size).and_return(10)
        expect(client.handle("EHLO test.example.com")).to include "250-SIZE #{10 * 1024 * 1024}"
      end

      it "continues every line but the last, so the client knows the response has ended" do
        allow(Postal::Config.smtp_server).to receive(:tls_enabled?).and_return(true)
        lines = client.handle("EHLO test.example.com")

        expect(lines[0..-2]).to all(start_with("250-"))
        expect(lines.last).to start_with("250 ")
      end

      context "when TLS is enabled" do
        it "returns capabilities include starttls" do
          allow(Postal::Config.smtp_server).to receive(:tls_enabled?).and_return(true)
          expect(client.handle("EHLO test.example.com")).to eq ["250-My capabilities are",
                                                                "250-STARTTLS",
                                                                size_capability,
                                                                *body_capabilities,
                                                                "250 AUTH CRAM-MD5 PLAIN LOGIN",]
        end

        it "does not offer starttls once the session is already encrypted" do
          allow(Postal::Config.smtp_server).to receive(:tls_enabled?).and_return(true)
          client.handle("EHLO test.example.com")
          client.handle("STARTTLS")

          expect(client).to be_tls
          expect(client.handle("EHLO test.example.com")).to eq ["250-My capabilities are",
                                                                size_capability,
                                                                *body_capabilities,
                                                                "250 AUTH CRAM-MD5 PLAIN LOGIN",]
        end
      end
    end
  end

end
