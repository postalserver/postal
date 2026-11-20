# frozen_string_literal: true

require "rails_helper"

describe ReceivedHeader do
  before do
    allow(DNSResolver.local).to receive(:ip_to_hostname).and_return("hostname.com")
  end

  describe ".generate" do
    context "when server is nil" do
      it "returns the correct string" do
        result = described_class.generate(nil, "testhelo", "1.1.1.1", :smtp)
        expect(result).to eq "from testhelo (hostname.com [1.1.1.1]) " \
                             "by #{Postal::Config.postal.smtp_hostname} " \
                             "with SMTP; #{Time.now.utc.rfc2822}"
      end
    end

    context "when server is provided with privacy_mode=true" do
      it "returns the correct string" do
        server = Server.new(privacy_mode: true)
        result = described_class.generate(server, "testhelo", "1.1.1.1", :smtp)
        expect(result).to eq "by #{Postal::Config.postal.smtp_hostname} " \
                             "with SMTP; #{Time.now.utc.rfc2822}"
      end
    end

    context "when server is provided with privacy_mode=false" do
      it "returns the correct string" do
        server = Server.new(privacy_mode: false)
        result = described_class.generate(server, "testhelo", "1.1.1.1", :smtp)
        expect(result).to eq "from testhelo (hostname.com [1.1.1.1]) " \
                             "by #{Postal::Config.postal.smtp_hostname} " \
                             "with SMTP; #{Time.now.utc.rfc2822}"
      end
    end

    context "when type is http" do
      it "returns the correct string" do
        result = described_class.generate(nil, "web-ui", "1.1.1.1", :http)
        expect(result).to eq "from web-ui (hostname.com [1.1.1.1]) " \
                             "by #{Postal::Config.postal.web_hostname} " \
                             "with HTTP; #{Time.now.utc.rfc2822}"
      end
    end
  end

  describe ".parse" do
    let(:smtp_hostname) { Postal::Config.postal.smtp_hostname }

    it "returns the HELO and IP address from a header written by .generate" do
      header = described_class.generate(nil, "mail.example.com", "192.0.2.10", :smtp)
      expect(described_class.parse(header)).to eq(helo: "mail.example.com", ip_address: "192.0.2.10")
    end

    it "reads an IPv6 address" do
      header = "from mail.example.com (hostname.com [2001:db8::1]) by #{smtp_hostname} with SMTP; #{Time.now.utc.rfc2822}"
      expect(described_class.parse(header)).to eq(helo: "mail.example.com", ip_address: "2001:db8::1")
    end

    it "returns nil for a header written with privacy mode on" do
      header = described_class.generate(Server.new(privacy_mode: true), "mail.example.com", "192.0.2.10", :smtp)
      expect(described_class.parse(header)).to be_nil
    end

    it "returns nil for a header written for the HTTP API" do
      header = described_class.generate(nil, "web-ui", "192.0.2.10", :http)
      expect(described_class.parse(header)).to be_nil
    end

    it "returns nil for a header another server wrote" do
      header = "from mail.example.com (hostname.com [192.0.2.10]) by mx.example.org with SMTP; #{Time.now.utc.rfc2822}"
      expect(described_class.parse(header)).to be_nil
    end

    it "returns nil for nil" do
      expect(described_class.parse(nil)).to be_nil
    end

    it "keeps a HELO address literal" do
      header = described_class.generate(nil, "[192.0.2.10]", "192.0.2.10", :smtp)
      expect(described_class.parse(header)).to eq(helo: "[192.0.2.10]", ip_address: "192.0.2.10")
    end

    context "when the HELO name copies the header's tail" do
      let(:helo) { "evil.example (x [203.0.113.9]) by #{smtp_hostname} with SMTP; Tue, 17 Nov 2026 00:00:00 +0000" }

      it "returns the address Postal wrote, not the one in the HELO name" do
        header = described_class.generate(nil, helo, "192.0.2.10", :smtp)
        expect(described_class.parse(header)).to eq(helo: nil, ip_address: "192.0.2.10")
      end
    end

    context "when the reverse DNS name copies the header's tail" do
      before do
        allow(DNSResolver.local).to receive(:ip_to_hostname)
          .and_return("x [203.0.113.9]) by #{smtp_hostname} with SMTP; y")
      end

      it "never returns the address in the reverse DNS name" do
        header = described_class.generate(nil, "mail.example.com", "192.0.2.10", :smtp)
        expect(described_class.parse(header)).to be_nil
      end
    end

    it "returns no HELO when the name has spaces or brackets" do
      header = described_class.generate(nil, "mail example (com)", "192.0.2.10", :smtp)
      expect(described_class.parse(header)).to eq(helo: nil, ip_address: "192.0.2.10")
    end

    it "returns nil when the address isn't an IP address" do
      header = "from mail.example.com (hostname.com [1.2.3]) by #{smtp_hostname} with SMTP; #{Time.now.utc.rfc2822}"
      expect(described_class.parse(header)).to be_nil
    end
  end
end
