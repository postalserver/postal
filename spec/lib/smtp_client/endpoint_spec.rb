# frozen_string_literal: true

require "rails_helper"

module SMTPClient

  RSpec.describe Endpoint do
    let(:ssl_mode) { SSLModes::AUTO }
    let(:server) { Server.new("mx1.example.com", port: 25, ssl_mode: ssl_mode) }
    let(:ip) { "1.2.3.4" }

    before do
      allow(Net::SMTP).to receive(:new).and_wrap_original do |original_method, *args|
        smtp = original_method.call(*args)
        allow(smtp).to receive(:start)
        allow(smtp).to receive(:started?).and_return(true)
        allow(smtp).to receive(:send_message)
        allow(smtp).to receive(:finish)
        smtp
      end
    end

    subject(:endpoint) { described_class.new(server, ip) }

    describe "#description" do
      it "returns a description for the endpoint" do
        expect(endpoint.description).to eq "1.2.3.4:25 (mx1.example.com)"
      end
    end

    describe "#ipv6?" do
      context "when the IP address is an IPv6 address" do
        let(:ip) { "2a00:67a0:a::1" }

        it "returns true" do
          expect(endpoint.ipv6?).to be true
        end
      end

      context "when the IP address is an IPv4 address" do
        it "returns false" do
          expect(endpoint.ipv6?).to be false
        end
      end
    end

    describe "#ipv4?" do
      context "when the IP address is an IPv4 address" do
        it "returns true" do
          expect(endpoint.ipv4?).to be true
        end
      end

      context "when the IP address is an IPv6 address" do
        let(:ip) { "2a00:67a0:a::1" }

        it "returns false" do
          expect(endpoint.ipv4?).to be false
        end
      end
    end

    describe "#start_smtp_session" do
      context "when given no source IP address" do
        it "creates a new Net::SMTP client with appropriate details" do
          client = endpoint.start_smtp_session
          expect(client.address).to eq "1.2.3.4"
        end

        it "sets the appropriate timeouts from the config" do
          client = endpoint.start_smtp_session
          expect(client.open_timeout).to eq Postal::Config.smtp_client.open_timeout
          expect(client.read_timeout).to eq Postal::Config.smtp_client.read_timeout
        end

        it "does not set a source address" do
          client = endpoint.start_smtp_session
          expect(client.source_address).to be_nil
        end

        it "sets the TLS hostname" do
          client = endpoint.start_smtp_session
          expect(client.tls_hostname).to eq "mx1.example.com"
        end

        it "starts the SMTP client the default HELO" do
          endpoint.start_smtp_session
          expect(endpoint.smtp_client).to have_received(:start).with(Postal::Config.postal.smtp_hostname)
        end

        context "when the SSL mode is Auto" do
          it "enables STARTTLS auto " do
            client = endpoint.start_smtp_session
            expect(client.starttls?).to eq :auto
          end
        end

        context "when the SSL mode is STARTLS" do
          let(:ssl_mode) { SSLModes::STARTTLS }

          it "as starttls as always" do
            client = endpoint.start_smtp_session
            expect(client.starttls?).to eq :always
          end
        end

        context "when the SSL mode is TLS" do
          let(:ssl_mode) { SSLModes::TLS }

          it "as starttls as always" do
            client = endpoint.start_smtp_session
            expect(client.tls?).to be true
          end
        end

        context "when the SSL mode is None" do
          let(:ssl_mode) { SSLModes::NONE }

          it "disables STARTTLS and TLS" do
            client = endpoint.start_smtp_session
            expect(client.starttls?).to be false
            expect(client.tls?).to be false
          end
        end

        context "when the SSL mode is Auto but ssl_allow is false" do
          it "disables STARTTLS and TLS" do
            client = endpoint.start_smtp_session(allow_ssl: false)
            expect(client.starttls?).to be false
            expect(client.tls?).to be false
          end
        end
      end

      context "when given a source IP address" do
        let(:ip_address) { create(:ip_address) }

        context "when the endpoint IP is ipv4" do
          it "sets the source address to the IPv4 address" do
            client = endpoint.start_smtp_session(source_ip_address: ip_address)
            expect(client.source_address).to eq ip_address.ipv4
          end
        end

        context "when the endpoint IP is ipv6" do
          let(:ip) { "2a00:67a0:a::1" }

          it "sets the source address to the IPv6 address" do
            client = endpoint.start_smtp_session(source_ip_address: ip_address)
            expect(client.source_address).to eq ip_address.ipv6
          end
        end

        it "starts the SMTP client with the IP addresses hostname" do
          endpoint.start_smtp_session(source_ip_address: ip_address)
          expect(endpoint.smtp_client).to have_received(:start).with(ip_address.hostname)
        end
      end
    end

    describe "#send_message" do
      context "when the smtp client has not been created" do
        it "raises an error" do
          expect { endpoint.send_message("", "", "") }.to raise_error Endpoint::SMTPSessionNotStartedError
        end
      end

      context "when the smtp client exists but is not started" do
        it "raises an error" do
          endpoint.start_smtp_session
          expect(endpoint.smtp_client).to receive(:started?).and_return(false)
          expect { endpoint.send_message("", "", "") }.to raise_error Endpoint::SMTPSessionNotStartedError
        end
      end

      context "when the smtp client is started" do
        before do
          endpoint.start_smtp_session
        end

        it "resets any previous errors" do
          expect(endpoint.smtp_client).to receive(:rset_errors)
          endpoint.send_message("test message", "from@example.com", "to@example.com")
        end

        it "sends the message to the SMTP client" do
          endpoint.send_message("test message", "from@example.com", "to@example.com")
          expect(endpoint.smtp_client).to have_received(:send_message).with("test message", "from@example.com", ["to@example.com"])
        end

        context "when the connection is reset during sending" do
          before do
            endpoint.start_smtp_session
            allow(endpoint.smtp_client).to receive(:send_message) do
              raise Errno::ECONNRESET
            end
          end

          it "closes the SMTP client" do
            expect(endpoint).to receive(:finish_smtp_session).and_call_original
            endpoint.send_message("test message", "", "")
          end

          it "retries sending the message once" do
            expect(endpoint).to receive(:send_message).twice.and_call_original
            endpoint.send_message("test message", "", "")
          end

          context "if the retry also fails" do
            it "raises the error" do
              allow(endpoint).to receive(:send_message).and_raise(Errno::ECONNRESET)
              expect { endpoint.send_message("test message", "", "") }.to raise_error(Errno::ECONNRESET)
            end
          end
        end
      end
    end

    describe "#reset_smtp_session" do
      it "calls rset on the client" do
        endpoint.start_smtp_session
        expect(endpoint.smtp_client).to receive(:rset)
        endpoint.reset_smtp_session
      end

      context "if there is an error" do
        it "finishes the smtp client" do
          endpoint.start_smtp_session
          allow(endpoint.smtp_client).to receive(:rset).and_raise(StandardError)
          expect(endpoint).to receive(:finish_smtp_session)
          endpoint.reset_smtp_session
        end
      end
    end

    describe "#finish_smtp_session" do
      it "calls finish on the client" do
        endpoint.start_smtp_session
        expect(endpoint.smtp_client).to receive(:finish)
        endpoint.finish_smtp_session
      end

      it "sets the smtp client to nil" do
        endpoint.start_smtp_session
        endpoint.finish_smtp_session
        expect(endpoint.smtp_client).to be_nil
      end

      context "if the client finish raises an error" do
        it "does not raise it" do
          endpoint.start_smtp_session
          allow(endpoint.smtp_client).to receive(:finish).and_raise(StandardError)
          expect { endpoint.finish_smtp_session }.not_to raise_error
        end
      end
    end

    describe ".default_helo_hostname" do
      context "when the configuration specifies a helo hostname" do
        before do
          allow(Postal::Config.dns).to receive(:helo_hostname).and_return("helo.example.com")
        end

        it "returns that" do
          expect(described_class.default_helo_hostname).to eq "helo.example.com"
        end
      end

      context "when the configuration does not specify a helo hostname but has an smtp hostname" do
        before do
          allow(Postal::Config.dns).to receive(:helo_hostname).and_return(nil)
          allow(Postal::Config.postal).to receive(:smtp_hostname).and_return("smtp.example.com")
        end

        it "returns the smtp hostname" do
          expect(described_class.default_helo_hostname).to eq "smtp.example.com"
        end
      end

      context "when the configuration has neither a helo hostname or an smtp hostname" do
        before do
          allow(Postal::Config.dns).to receive(:helo_hostname).and_return(nil)
          allow(Postal::Config.postal).to receive(:smtp_hostname).and_return(nil)
        end

        it "returns localhost" do
          expect(described_class.default_helo_hostname).to eq "localhost"
        end
      end
    end
  end

end
