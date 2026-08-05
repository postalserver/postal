# frozen_string_literal: true

require "rails_helper"

RSpec.describe Postal::HTTP::AddressGuard do
  describe ".safe_connect_address" do
    subject(:call) { described_class.safe_connect_address(host) }

    before do
      allow(Postal::Config.postal).to receive(:allowed_request_destinations).and_return(allowlist)
    end

    let(:allowlist) { [] }

    context "when given a public IP literal" do
      let(:host) { "93.184.216.34" }

      it "returns the address to connect to" do
        expect(call).to eq "93.184.216.34"
      end
    end

    context "when given a public IPv6 literal" do
      let(:host) { "2606:2800:220:1:248:1893:25c8:1946" }

      before { allow(described_class).to receive(:ipv6_supported?).and_return(true) }

      it "returns the address to connect to" do
        expect(call).to eq "2606:2800:220:1:248:1893:25c8:1946"
      end
    end

    [
      "127.0.0.1",
      "10.0.0.1",
      "172.16.5.4",
      "192.168.1.1",
      "169.254.169.254", # cloud metadata
      "100.64.0.1",      # carrier-grade NAT
      "0.0.0.0",
      "::1",
      "fd00::1",         # unique-local IPv6
      "fe80::1",         # link-local IPv6
      "::ffff:127.0.0.1", # IPv4-mapped loopback
    ].each do |blocked|
      context "when given the blocked address #{blocked}" do
        let(:host) { blocked }

        it "raises BlockedDestinationError" do
          expect { call }.to raise_error(Postal::HTTP::BlockedDestinationError)
        end
      end
    end

    context "when given a hostname that resolves to a public address" do
      let(:host) { "example.com" }

      before do
        allow(Resolv).to receive(:getaddresses).with(host).and_return(["93.184.216.34"])
      end

      it "returns the resolved address" do
        expect(call).to eq "93.184.216.34"
      end
    end

    context "when given a hostname that resolves to a private address" do
      let(:host) { "internal.example.com" }

      before do
        allow(Resolv).to receive(:getaddresses).with(host).and_return(["10.1.2.3"])
      end

      it "raises BlockedDestinationError" do
        expect { call }.to raise_error(Postal::HTTP::BlockedDestinationError)
      end
    end

    context "when a hostname resolves to both a public and a private address" do
      let(:host) { "rebind.example.com" }

      before do
        allow(Resolv).to receive(:getaddresses).with(host).and_return(["93.184.216.34", "127.0.0.1"])
      end

      it "raises BlockedDestinationError because one address is blocked" do
        expect { call }.to raise_error(Postal::HTTP::BlockedDestinationError)
      end
    end

    context "when a hostname resolves to both IPv4 and IPv6 addresses" do
      let(:host) { "dualstack.example.com" }
      let(:ipv6) { "2606:2800:220:1:248:1893:25c8:1946" }

      before do
        allow(Resolv).to receive(:getaddresses).with(host).and_return([ipv6, "93.184.216.34"])
      end

      context "and the server does not support IPv6" do
        before { allow(described_class).to receive(:ipv6_supported?).and_return(false) }

        it "connects over IPv4" do
          expect(call).to eq "93.184.216.34"
        end
      end

      context "and the server supports IPv6" do
        before { allow(described_class).to receive(:ipv6_supported?).and_return(true) }

        it "still prefers IPv4 for predictability" do
          expect(call).to eq "93.184.216.34"
        end
      end
    end

    context "when a hostname resolves only to an IPv6 address" do
      let(:host) { "v6only.example.com" }
      let(:ipv6) { "2606:2800:220:1:248:1893:25c8:1946" }

      before do
        allow(Resolv).to receive(:getaddresses).with(host).and_return([ipv6])
      end

      context "and the server does not support IPv6" do
        before { allow(described_class).to receive(:ipv6_supported?).and_return(false) }

        it "raises a SocketError because the address is unreachable" do
          expect { call }.to raise_error(SocketError)
        end
      end

      context "and the server supports IPv6" do
        before { allow(described_class).to receive(:ipv6_supported?).and_return(true) }

        it "connects over IPv6" do
          expect(call).to eq ipv6
        end
      end
    end

    context "when a hostname cannot be resolved" do
      let(:host) { "nope.example.com" }

      before do
        allow(Resolv).to receive(:getaddresses).with(host).and_return([])
      end

      it "raises BlockedDestinationError" do
        expect { call }.to raise_error(Postal::HTTP::BlockedDestinationError, /resolve/)
      end
    end

    context "when the host is blank" do
      let(:host) { "" }

      it "raises BlockedDestinationError" do
        expect { call }.to raise_error(Postal::HTTP::BlockedDestinationError)
      end
    end

    context "when a blocked address is allowlisted by CIDR" do
      let(:host) { "10.0.0.5" }
      let(:allowlist) { ["10.0.0.0/8"] }

      it "returns the address" do
        expect(call).to eq "10.0.0.5"
      end
    end

    context "when a blocked address is allowlisted by exact IP" do
      let(:host) { "127.0.0.1" }
      let(:allowlist) { ["127.0.0.1"] }

      it "returns the address" do
        expect(call).to eq "127.0.0.1"
      end
    end

    context "when a hostname resolving to a private address is allowlisted by name" do
      let(:host) { "internal.example.com" }
      let(:allowlist) { ["internal.example.com"] }

      before do
        allow(Resolv).to receive(:getaddresses).with(host).and_return(["10.1.2.3"])
      end

      it "returns the resolved address" do
        expect(call).to eq "10.1.2.3"
      end
    end
  end
end
