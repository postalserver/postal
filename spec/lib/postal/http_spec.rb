# frozen_string_literal: true

require "rails_helper"

RSpec.describe Postal::HTTP do
  before do
    allow(Postal::Config.postal).to receive(:allowed_request_destinations).and_return([])
  end

  describe ".post" do
    context "when the host resolves to a blocked address" do
      before do
        allow(Resolv).to receive(:getaddresses).with("internal.example.com").and_return(["127.0.0.1"])
      end

      it "does not make a request and returns a blocked-destination result" do
        result = described_class.post("http://internal.example.com/hook", json: "{}")
        expect(result[:code]).to eq(-4)
        expect(result[:body]).to match(/not permitted/)
        expect(WebMock).not_to have_requested(:post, "http://internal.example.com/hook")
      end
    end

    context "when resolving the host raises an error" do
      before do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_raise(Resolv::ResolvError, "resolver failed")
      end

      it "returns a connection error result" do
        result = described_class.post("http://example.com/hook", json: "{}")
        expect(result[:code]).to eq(-2)
        expect(result[:body]).to match(/resolver failed/)
        expect(WebMock).not_to have_requested(:post, "http://example.com/hook")
      end
    end

    context "when resolving the host exceeds the request timeout" do
      before do
        allow(Resolv).to receive(:getaddresses).with("example.com") do
          sleep 0.2
          ["93.184.216.34"]
        end
      end

      it "returns a timeout result before making a request" do
        result = described_class.post("http://example.com/hook", json: "{}", timeout: 0.05)
        expect(result[:code]).to eq(-1)
        expect(WebMock).not_to have_requested(:post, "http://example.com/hook")
      end
    end

    context "when the host resolves to a public address" do
      before do
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.34"])
        stub_request(:post, "http://example.com/hook").to_return(status: 200, body: "OK")
      end

      it "pins the connection to the validated address and performs the request" do
        expect_any_instance_of(Net::HTTP).to receive(:ipaddr=).with("93.184.216.34").and_call_original
        result = described_class.post("http://example.com/hook", json: "{}")
        expect(result[:code]).to eq(200)
        expect(WebMock).to have_requested(:post, "http://example.com/hook")
      end
    end

    context "when the blocked host is allowlisted" do
      before do
        allow(Postal::Config.postal).to receive(:allowed_request_destinations).and_return(["internal.example.com"])
        allow(Resolv).to receive(:getaddresses).with("internal.example.com").and_return(["10.0.0.5"])
        stub_request(:post, "http://internal.example.com/hook").to_return(status: 200, body: "OK")
      end

      it "performs the request" do
        result = described_class.post("http://internal.example.com/hook", json: "{}")
        expect(result[:code]).to eq(200)
        expect(WebMock).to have_requested(:post, "http://internal.example.com/hook")
      end
    end
  end
end
