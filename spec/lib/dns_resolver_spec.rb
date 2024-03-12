# frozen_string_literal: true

require "rails_helper"

RSpec.describe DNSResolver do
  subject(:resolver) { described_class.local }

  # Now, we could mock everything in here which would give us some comfort
  # but I do think that we'll benefit more from having a full E2E test here
  # so we'll test this using values which we know to be fairly static and
  # that are within our control.

  describe "#a" do
    it "returns a list of IP addresses" do
      expect(resolver.a("www.dnstest.postalserver.io").sort).to eq ["1.2.3.4", "2.3.4.5"]
    end

    it "resolves a domain name containing an emoji" do
      expect(resolver.a("☺.dnstest.postalserver.io").sort).to eq ["3.4.5.6"]
    end

    it "returns an empty array when timeout is exceeded" do
      allow(Postal::Config.dns).to receive(:timeout).and_return(0.00001)
      expect(resolver.a("www.dnstest.postalserver.io")).to eq []
    end

    context "when raise_timeout_errors is true" do
      it "returns a list of IP addresses" do
        expect(resolver.a("www.dnstest.postalserver.io", raise_timeout_errors: true).sort).to eq ["1.2.3.4", "2.3.4.5"]
      end

      it "raises an error when the timeout is exceeded" do
        allow(Postal::Config.dns).to receive(:timeout).and_return(0.00001)
        expect do
          resolver.a("www.dnstest.postalserver.io", raise_timeout_errors: true)
        end.to raise_error(Resolv::ResolvError, /timeout/)
      end
    end
  end

  describe "#aaaa" do
    it "returns a list of IP addresses" do
      expect(resolver.aaaa("www.dnstest.postalserver.io").sort).to eq ["2a00:67a0:a::1", "2a00:67a0:a::2"]
    end

    it "returns an empty array when timeout is exceeded" do
      allow(Postal::Config.dns).to receive(:timeout).and_return(0.00001)
      expect(resolver.aaaa("www.dnstest.postalserver.io")).to eq []
    end

    context "when raise_timeout_errors is true" do
      it "returns a list of IP addresses" do
        expect(resolver.aaaa("www.dnstest.postalserver.io", raise_timeout_errors: true).sort).to eq ["2a00:67a0:a::1", "2a00:67a0:a::2"]
      end

      it "raises an error when the timeout is exceeded" do
        allow(Postal::Config.dns).to receive(:timeout).and_return(0.00001)
        expect do
          resolver.aaaa("www.dnstest.postalserver.io", raise_timeout_errors: true)
        end.to raise_error(Resolv::ResolvError, /timeout/)
      end
    end
  end

  describe "#txt" do
    it "returns a list of TXT records" do
      expect(resolver.txt("dnstest.postalserver.io").sort).to eq [
        "an example txt record",
        "another example",
      ]
    end

    it "returns an empty array when timeout is exceeded" do
      allow(Postal::Config.dns).to receive(:timeout).and_return(0.00001)
      expect(resolver.txt("dnstest.postalserver.io")).to eq []
    end

    context "when raise_timeout_errors is true" do
      it "returns a list of TXT records" do
        expect(resolver.txt("dnstest.postalserver.io", raise_timeout_errors: true).sort).to eq [
          "an example txt record",
          "another example",
        ]
      end

      it "raises an error when the timeout is exceeded" do
        allow(Postal::Config.dns).to receive(:timeout).and_return(0.00001)
        expect do
          resolver.txt("dnstest.postalserver.io", raise_timeout_errors: true)
        end.to raise_error(Resolv::ResolvError, /timeout/)
      end
    end
  end

  describe "#cname" do
    it "returns a list of CNAME records" do
      expect(resolver.cname("cname.dnstest.postalserver.io")).to eq ["www.dnstest.postalserver.io"]
    end

    it "returns an empty array when timeout is exceeded" do
      allow(Postal::Config.dns).to receive(:timeout).and_return(0.00001)
      expect(resolver.cname("cname.dnstest.postalserver.io")).to eq []
    end

    context "when raise_timeout_errors is true" do
      it "returns a list of CNAME records" do
        expect(resolver.cname("cname.dnstest.postalserver.io", raise_timeout_errors: true)).to eq ["www.dnstest.postalserver.io"]
      end

      it "raises an error when the timeout is exceeded" do
        allow(Postal::Config.dns).to receive(:timeout).and_return(0.00001)
        expect do
          resolver.cname("cname.dnstest.postalserver.io", raise_timeout_errors: true)
        end.to raise_error(Resolv::ResolvError, /timeout/)
      end
    end
  end

  describe "#mx" do
    it "returns a list of MX records" do
      expect(resolver.mx("dnstest.postalserver.io")).to eq [
        [10, "mx1.dnstest.postalserver.io"],
        [20, "mx2.dnstest.postalserver.io"],
      ]
    end

    it "returns an empty array when timeout is exceeded" do
      allow(Postal::Config.dns).to receive(:timeout).and_return(0.00001)
      expect(resolver.mx("dnstest.postalserver.io")).to eq []
    end

    context "when raise_timeout_errors is true" do
      it "returns a list of MX records" do
        expect(resolver.mx("dnstest.postalserver.io", raise_timeout_errors: true)).to eq [
          [10, "mx1.dnstest.postalserver.io"],
          [20, "mx2.dnstest.postalserver.io"],
        ]
      end

      it "raises an error when the timeout is exceeded" do
        allow(Postal::Config.dns).to receive(:timeout).and_return(0.00001)
        expect do
          resolver.mx("dnstest.postalserver.io", raise_timeout_errors: true)
        end.to raise_error(Resolv::ResolvError, /timeout/)
      end
    end
  end

  describe "#effective_ns" do
    it "returns the nameserver names that are authoritative for the given domain" do
      expect(resolver.effective_ns("postalserver.io").sort).to eq [
        "prestigious-honeybadger.katapultdns.com",
        "the-cake-is-a-lie.katapultdns.com",
      ]
    end

    it "returns an empty array when timeout is exceeded" do
      allow(Postal::Config.dns).to receive(:timeout).and_return(0.00001)
      expect(resolver.effective_ns("postalserver.io")).to eq []
    end

    context "when raise_timeout_errors is true" do
      it "returns a list of NS records" do
        expect(resolver.effective_ns("postalserver.io", raise_timeout_errors: true).sort).to eq [
          "prestigious-honeybadger.katapultdns.com",
          "the-cake-is-a-lie.katapultdns.com",
        ]
      end

      it "raises an error when the timeout is exceeded" do
        allow(Postal::Config.dns).to receive(:timeout).and_return(0.00001)
        expect do
          resolver.effective_ns("postalserver.io", raise_timeout_errors: true)
        end.to raise_error(Resolv::ResolvError, /timeout/)
      end
    end
  end

  describe "#ip_to_hostname" do
    it "returns the hostname for the given IP" do
      expect(resolver.ip_to_hostname("151.252.1.100")).to eq "ns1.katapultdns.com"
    end

    it "returns the IP when the timeout is exceeded" do
      allow(Postal::Config.dns).to receive(:timeout).and_return(0.00001)
      expect(resolver.ip_to_hostname("151.252.1.100")).to eq "151.252.1.100"
    end

    context "when raise_timeout_errors is true" do
      it "returns the hostname for the given IP" do
        expect(resolver.ip_to_hostname("151.252.1.100", raise_timeout_errors: true)).to eq "ns1.katapultdns.com"
      end

      it "raises an error when the timeout is exceeded" do
        allow(Postal::Config.dns).to receive(:timeout).and_return(0.00001)
        expect do
          resolver.ip_to_hostname("151.252.1.100", raise_timeout_errors: true)
        end.to raise_error(Resolv::ResolvError, /timeout/)
      end
    end
  end

  describe ".for_domain" do
    it "finds the effective nameservers for a given domain and returns them" do
      resolver = described_class.for_domain("dnstest.postalserver.io")
      expect(resolver.nameservers.sort).to eq ["151.252.1.100", "151.252.2.100"]
    end
  end

  describe ".local" do
    after do
      # Remove all cached values for the local resolver
      DNSResolver.instance_variable_set(:@local, nil)
    end

    it "returns a resolver with the local machine's resolvers" do
      resolver = described_class.local
      expect(resolver.nameservers).to be_a Array
      expect(resolver.nameservers).to_not be_empty
    end

    context "when there is no resolv.conf" do
      it "raises an error" do
        allow(File).to receive(:file?).with("/etc/resolv.conf").and_return(false)
        expect { described_class.local }.to raise_error(DNSResolver::LocalResolversUnavailableError,
                                                        /no resolver config found at/i)
      end
    end

    context "when no nameservers are found in resolv.conf" do
      it "raises an error" do
        allow(Resolv::DNS::Config).to receive(:parse_resolv_conf).with("/etc/resolv.conf").and_return({})
        expect { described_class.local }.to raise_error(DNSResolver::LocalResolversUnavailableError,
                                                        /could not find nameservers in/i)
      end
    end

    context "when an empty array of nameserver is found in resolv.conf" do
      it "raises an error" do
        allow(Resolv::DNS::Config).to receive(:parse_resolv_conf).with("/etc/resolv.conf")
                                                                 .and_return({ nameserver: [] })
        expect { described_class.local }.to raise_error(DNSResolver::LocalResolversUnavailableError,
                                                        /could not find nameservers in/i)
      end
    end
  end

  context "when using a resolver for a domain" do
    subject(:resolver) { described_class.for_domain("dnstest.postalserver.io") }

    it "will not return domains that are not hosted on that server" do
      expect(resolver.a("example.com")).to eq []
    end
  end
end
