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

    describe "relay authentication" do
      let(:server) do
        Server.new("relay.example.com",
                   port: 587,
                   ssl_mode: SSLModes::STARTTLS,
                   username: username,
                   password: password,
                   authentication: authentication)
      end
      let(:username) { "smtp-user" }
      let(:password) { "p:ss+word" }
      let(:authentication) { nil }
      let(:encrypted) { true }
      let(:cram_md5) { false }
      let(:plain) { false }
      let(:login) { false }

      before do
        allow(Net::SMTP).to receive(:new).and_wrap_original do |original_method, *args|
          smtp = original_method.call(*args)
          allow(smtp).to receive(:start)
          allow(smtp).to receive(:started?).and_return(true)
          allow(smtp).to receive(:finish)
          allow(smtp).to receive(:authenticate)
          allow(smtp).to receive(:tls?).and_return(encrypted)
          allow(smtp).to receive(:capable_cram_md5_auth?).and_return(cram_md5)
          allow(smtp).to receive(:capable_plain_auth?).and_return(plain)
          allow(smtp).to receive(:capable_login_auth?).and_return(login)
          smtp
        end
      end

      def start_session
        endpoint.start_smtp_session
        endpoint.smtp_client
      end

      context "when the relay carries no credentials" do
        let(:username) { nil }

        it "does not authenticate" do
          expect(start_session).not_to have_received(:authenticate)
        end
      end

      context "when the relay offers CRAM-MD5 as well as PLAIN" do
        let(:cram_md5) { true }
        let(:plain) { true }

        it "uses the mechanism which does not put the secret on the wire" do
          expect(start_session).to have_received(:authenticate).with("smtp-user", "p:ss+word", :cram_md5)
        end
      end

      context "when the relay offers only PLAIN" do
        let(:plain) { true }

        it "authenticates with PLAIN" do
          expect(start_session).to have_received(:authenticate).with("smtp-user", "p:ss+word", :plain)
        end
      end

      context "when the relay offers only the older LOGIN" do
        let(:login) { true }

        it "falls back to LOGIN rather than leaving the relay unreachable" do
          expect(start_session).to have_received(:authenticate).with("smtp-user", "p:ss+word", :login)
        end
      end

      context "when the relay advertises no mechanism at all" do
        it "refuses rather than presenting the credential to an unknown peer" do
          expect { endpoint.start_smtp_session }
            .to raise_error(described_class::AuthenticationNotSupportedError, /does not advertise/)
        end
      end

      context "when the relay names a mechanism" do
        let(:authentication) { "login" }
        let(:cram_md5) { true }

        it "uses the named mechanism even when a stronger one is offered" do
          expect(start_session).to have_received(:authenticate).with("smtp-user", "p:ss+word", :login)
        end
      end

      context "when the relay names a mechanism which does not exist" do
        let(:authentication) { "kerberos" }

        it "raises with the mechanisms it accepts" do
          expect { endpoint.start_smtp_session }.to raise_error(ArgumentError, /plain, login, cram_md5/)
        end
      end

      context "when the session is not encrypted" do
        let(:plain) { true }
        let(:encrypted) { false }

        it "authenticates but warns that the credential is readable on the wire" do
          expect(Postal.logger).to receive(:warn).with(/unencrypted/)

          expect(start_session).to have_received(:authenticate).with("smtp-user", "p:ss+word", :plain)
        end
      end
    end

    describe ".transmitted_size" do
      it "counts a bare line ending as the CRLF the transfer sends" do
        expect(described_class.transmitted_size("hello\n")).to eq 7
      end

      it "does not count a line ending twice when it is already CRLF" do
        expect(described_class.transmitted_size("hello\r\n")).to eq 7
      end

      it "counts the dot that the transfer doubles on a line which starts with one" do
        expect(described_class.transmitted_size(".hello\n")).to eq 9
      end

      it "counts a last line which has no line ending of its own" do
        expect(described_class.transmitted_size("hello")).to eq 7
      end

      it "counts every line of a multi-line message" do
        expect(described_class.transmitted_size("a\nb\nc\n")).to eq 9
      end

      it "returns zero for an empty message" do
        expect(described_class.transmitted_size("")).to eq 0
      end
    end

    describe "a message larger than the server accepts" do
      let(:capabilities) { { "SIZE" => ["1024"] } }

      before do
        allow(Net::SMTP).to receive(:new).and_wrap_original do |original_method, *args|
          smtp = original_method.call(*args)
          allow(smtp).to receive(:start)
          allow(smtp).to receive(:started?).and_return(true)
          allow(smtp).to receive(:finish)
          allow(smtp).to receive(:rset_errors)
          allow(smtp).to receive(:send_message)
          allow(smtp).to receive(:capabilities).and_return(capabilities)
          smtp
        end

        endpoint.start_smtp_session
      end

      context "when the message fits" do
        it "sends it" do
          endpoint.send_message("a" * 100, "from@example.com", "to@example.com")

          expect(endpoint.smtp_client).to have_received(:send_message)
        end
      end

      context "when the message is exactly the size the server accepts" do
        it "sends it, because the reply is a maximum and not a limit to stay under" do
          endpoint.send_message("a" * 1022, "from@example.com", "to@example.com")

          expect(endpoint.smtp_client).to have_received(:send_message)
        end
      end

      context "when the message is larger than the server accepts" do
        it "refuses it" do
          expect { endpoint.send_message("a" * 4096, "from@example.com", "to@example.com") }
            .to raise_error(described_class::MessageTooLargeError, /up to 1024 bytes but this one is 4098 bytes/)
        end

        it "refuses it without transferring any of it" do
          expect { endpoint.send_message("a" * 4096, "from@example.com", "to@example.com") }
            .to raise_error(described_class::MessageTooLargeError)

          expect(endpoint.smtp_client).not_to have_received(:send_message)
        end

        it "measures the message as it would be transferred, not as it is stored" do
          # Five hundred single-character lines are 999 bytes as stored but
          # 1500 bytes on the wire once each has its CRLF.
          expect { endpoint.send_message(Array.new(500, "a").join("\n"), "from@example.com", "to@example.com") }
            .to raise_error(described_class::MessageTooLargeError, /this one is 1500 bytes/)
        end
      end

      context "when the server advertises a size of zero, which publishes no limit" do
        let(:capabilities) { { "SIZE" => ["0"] } }

        it "sends the message" do
          endpoint.send_message("a" * 4096, "from@example.com", "to@example.com")

          expect(endpoint.smtp_client).to have_received(:send_message)
        end
      end

      context "when the server advertises no size at all" do
        let(:capabilities) { { "PIPELINING" => [] } }

        it "sends the message" do
          endpoint.send_message("a" * 4096, "from@example.com", "to@example.com")

          expect(endpoint.smtp_client).to have_received(:send_message)
        end
      end

      context "when the session was never handed any capabilities" do
        let(:capabilities) { nil }

        it "sends the message" do
          endpoint.send_message("a" * 4096, "from@example.com", "to@example.com")

          expect(endpoint.smtp_client).to have_received(:send_message)
        end
      end
    end

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

        context "when the SSL mode is STARTTLS" do
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
