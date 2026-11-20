# frozen_string_literal: true

require "rails_helper"

module Postal
  module MessageInspectors

    RSpec.describe Rspamd do
      let(:config) { double("Config", host: "rspamd.example.com", port: 11_334, ssl: false, password: nil, flags: nil) }
      let(:server) { create(:server) }
      let(:smtp_hostname) { Postal::Config.postal.smtp_hostname }
      let(:received) { "from mail.example.com (hostname.com [192.0.2.10]) by #{smtp_hostname} with SMTP; #{Time.now.utc.rfc2822}" }
      let(:message) do
        MessageFactory.incoming(server) do |_msg, mail|
          mail["Received"] = received
        end
      end
      let(:scope) { :incoming }
      let(:inspection) { MessageInspection.new(message, scope) }
      let(:response) { { "symbols" => {} } }

      subject(:inspector) { described_class.new(config) }

      before do
        stub_request(:post, "http://rspamd.example.com:11334/checkv2")
          .to_return(status: 200, body: response.to_json)
      end

      describe "the request" do
        it "sends the sending server's IP address and HELO" do
          inspector.inspect_message(inspection)
          expect(WebMock).to have_requested(:post, "http://rspamd.example.com:11334/checkv2")
            .with(headers: { "Ip" => "192.0.2.10", "Helo" => "mail.example.com" })
        end

        context "when the HELO name copies the Received header's tail" do
          let(:forged) { "evil.example (x [203.0.113.9]) by #{smtp_hostname} with SMTP; #{Time.now.utc.rfc2822}" }
          let(:received) { "from #{forged} (hostname.com [192.0.2.10]) by #{smtp_hostname} with SMTP; #{Time.now.utc.rfc2822}" }

          it "sends the address Postal wrote and no HELO" do
            inspector.inspect_message(inspection)
            expect(WebMock).to(have_requested(:post, "http://rspamd.example.com:11334/checkv2")
              .with { |req| req.headers["Ip"] == "192.0.2.10" && !req.headers.key?("Helo") })
          end
        end

        context "when the Received header was written with privacy mode on" do
          let(:received) { "by #{smtp_hostname} with SMTP; #{Time.now.utc.rfc2822}" }

          it "sends no IP address or HELO" do
            inspector.inspect_message(inspection)
            expect(WebMock).to(have_requested(:post, "http://rspamd.example.com:11334/checkv2")
              .with { |req| !req.headers.key?("Ip") && !req.headers.key?("Helo") })
          end
        end

        context "when the message is outgoing" do
          let(:message) { MessageFactory.outgoing(server) }
          let(:scope) { :outgoing }

          it "sends an empty IP address and no HELO" do
            inspector.inspect_message(inspection)
            expect(WebMock).to(have_requested(:post, "http://rspamd.example.com:11334/checkv2")
              .with { |req| req.headers["Ip"] == "" && !req.headers.key?("Helo") })
          end
        end
      end

      describe "Authentication-Results" do
        let(:value) { "mx.example.com; spf=pass smtp.mailfrom=example.com" }

        context "when rspamd sends the header as a string" do
          let(:response) { { "symbols" => {}, "milter" => { "add_headers" => { "Authentication-Results" => value } } } }

          it "adds it to the inspection's headers" do
            inspector.inspect_message(inspection)
            expect(inspection.headers).to eq ["Authentication-Results: #{value}"]
          end
        end

        context "when rspamd sends the header as an object" do
          let(:response) { { "symbols" => {}, "milter" => { "add_headers" => { "Authentication-Results" => { "value" => value, "order" => 0 } } } } }

          it "adds it to the inspection's headers" do
            inspector.inspect_message(inspection)
            expect(inspection.headers).to eq ["Authentication-Results: #{value}"]
          end
        end

        context "when rspamd sends an array" do
          let(:response) { { "symbols" => {}, "milter" => { "add_headers" => { "Authentication-Results" => [{ "value" => value }] } } } }

          it "adds the first one" do
            inspector.inspect_message(inspection)
            expect(inspection.headers).to eq ["Authentication-Results: #{value}"]
          end
        end

        context "when the value is folded with bare newlines" do
          let(:response) { { "symbols" => {}, "milter" => { "add_headers" => { "Authentication-Results" => "mx.example.com;\n\tspf=pass" } } } }

          it "folds it with CRLF" do
            inspector.inspect_message(inspection)
            expect(inspection.headers).to eq ["Authentication-Results: mx.example.com;\r\n\tspf=pass"]
          end
        end

        context "when the value has a line break that isn't folding" do
          let(:response) { { "symbols" => {}, "milter" => { "add_headers" => { "Authentication-Results" => "mx.example.com;\r\nX-Injected: yes" } } } }

          it "adds nothing" do
            inspector.inspect_message(inspection)
            expect(inspection.headers).to be_empty
          end
        end

        context "when the message is outgoing" do
          let(:message) { MessageFactory.outgoing(server) }
          let(:scope) { :outgoing }
          let(:response) { { "symbols" => {}, "milter" => { "add_headers" => { "Authentication-Results" => value } } } }

          it "adds nothing" do
            inspector.inspect_message(inspection)
            expect(inspection.headers).to be_empty
          end
        end

        context "when rspamd asks for no headers" do
          it "adds nothing" do
            inspector.inspect_message(inspection)
            expect(inspection.headers).to be_empty
          end
        end
      end

      context "when rspamd can't be reached" do
        before do
          stub_request(:post, "http://rspamd.example.com:11334/checkv2").to_return(status: 500)
        end

        it "records an error spam check and adds no headers" do
          inspector.inspect_message(inspection)
          expect(inspection.spam_checks.map(&:code)).to eq ["ERROR"]
          expect(inspection.headers).to be_empty
        end
      end
    end

  end
end
