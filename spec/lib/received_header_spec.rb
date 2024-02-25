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
end
