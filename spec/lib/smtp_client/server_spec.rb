# frozen_string_literal: true

require "rails_helper"

module SMTPClient

  RSpec.describe Server do
    let(:hostname) { "example.com" }
    let(:port) { 25 }
    let(:ssl_mode) { SSLModes::AUTO }

    subject(:server) { described_class.new(hostname, port: port, ssl_mode: ssl_mode) }

    describe "#endpoints" do
      context "when there are A and AAAA records" do
        before do
          allow(DNSResolver.local).to receive(:a).and_return(["1.2.3.4", "2.3.4.5"])
          allow(DNSResolver.local).to receive(:aaaa).and_return(["2a00::67a0:a::1234", "2a00::67a0:a::2345"])
        end

        it "asks the resolver for the A and AAAA records for the hostname" do
          server.endpoints
          expect(DNSResolver.local).to have_received(:a).with(hostname).once
          expect(DNSResolver.local).to have_received(:aaaa).with(hostname).once
        end

        it "returns endpoints for ipv6 addresses followed by ipv4" do
          expect(server.endpoints).to match [
            have_attributes(ip_address: "2a00::67a0:a::1234"),
            have_attributes(ip_address: "2a00::67a0:a::2345"),
            have_attributes(ip_address: "1.2.3.4"),
            have_attributes(ip_address: "2.3.4.5"),
          ]
        end
      end

      context "when there are just A records" do
        before do
          allow(DNSResolver.local).to receive(:a).and_return(["1.2.3.4", "2.3.4.5"])
          allow(DNSResolver.local).to receive(:aaaa).and_return([])
        end

        it "returns ipv4 endpoints" do
          expect(server.endpoints).to match [
            have_attributes(ip_address: "1.2.3.4"),
            have_attributes(ip_address: "2.3.4.5"),
          ]
        end
      end

      context "when there are just AAAA records" do
        before do
          allow(DNSResolver.local).to receive(:a).and_return([])
          allow(DNSResolver.local).to receive(:aaaa).and_return(["2a00::67a0:a::1234", "2a00::67a0:a::2345"])
        end

        it "returns ipv6 endpoints" do
          expect(server.endpoints).to match [
            have_attributes(ip_address: "2a00::67a0:a::1234"),
            have_attributes(ip_address: "2a00::67a0:a::2345"),
          ]
        end
      end
    end
  end

end
