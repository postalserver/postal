# frozen_string_literal: true

require "rails_helper"

RSpec.describe DNSResolver do
  subject(:resolver) { described_class.new }

  # Now, we could mock everything in here which would give us some comfort
  # but I do think that we'll benefit more from having a full E2E test here
  # so we'll test this using values which we know to be fairly static and
  # that are within our control.

  describe "#a" do
    it "returns a list of IP addresses" do
      expect(resolver.a("www.test.postalserver.io").sort).to eq ["1.2.3.4", "2.3.4.5"]
    end
  end

  describe "#aaaa" do
    it "returns a list of IP addresses" do
      expect(resolver.aaaa("www.test.postalserver.io").sort).to eq ["2a00:67a0:a::1", "2a00:67a0:a::2"]
    end
  end

  describe "#txt" do
    it "returns a list of TXT records" do
      expect(resolver.txt("test.postalserver.io").sort).to eq [
        "an example txt record",
        "another example"
      ]
    end
  end

  describe "#cname" do
    it "returns a list of CNAME records" do
      expect(resolver.cname("cname.test.postalserver.io")).to eq ["www.test.postalserver.io"]
    end
  end

  describe "#mx" do
    it "returns a list of MX records" do
      expect(resolver.mx("test.postalserver.io")).to eq [
        [10, "mx1.test.postalserver.io"],
        [20, "mx2.test.postalserver.io"]
      ]
    end
  end

  describe "#effective_ns" do
    it "returns the nameserver names that are authoritative for the given domain" do
      expect(resolver.effective_ns("postalserver.io").sort).to eq [
        "prestigious-honeybadger.katapultdns.com",
        "the-cake-is-a-lie.katapultdns.com"
      ]
    end
  end

  describe "#ip_to_hostname" do
    it "returns the hostname for the given IP" do
      expect(resolver.ip_to_hostname("151.252.1.100")).to eq "ns1.katapultdns.com"
    end
  end

  describe ".for_domain" do
    it "finds the effective nameservers for a given domain and returns them" do
      resolver = described_class.for_domain("test.postalserver.io")
      expect(resolver.nameservers.sort).to eq ["151.252.1.100", "151.252.2.100"]
    end
  end

  describe ".local" do
    it "returns a resolver with no nameservers" do
      resolver = described_class.local
      expect(resolver.nameservers).to be nil
    end
  end

  context "when using a resolver for a domain" do
    subject(:resolver) { described_class.for_domain("test.postalserver.io") }

    it "will not return domains that are not hosted on that server" do
      expect(resolver.a("example.com")).to eq []
    end
  end
end
