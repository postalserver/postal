# frozen_string_literal: true

require "rails_helper"

module SMTPServer

  describe Client do
    let(:ip_address) { nil }
    subject(:client) { described_class.new(ip_address) }

    describe "PROXY" do
      context "when the proxy header is sent correctly" do
        it "sets the IP address" do
          expect(client.handle("PROXY TCP4 1.1.1.1 2.2.2.2 1111 2222")).to eq "220 #{Postal::Config.postal.smtp_hostname} ESMTP Postal/#{client.trace_id}"
          expect(client.ip_address).to eq "1.1.1.1"
        end
      end

      context "when the proxy header is not valid" do
        it "returns an error" do
          expect(client.handle("PROXY TCP4")).to eq "502 Proxy Error"
          expect(client.finished?).to be true
        end
      end
    end
  end

end
