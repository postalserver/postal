# frozen_string_literal: true

require "rails_helper"

module SMTPServer

  describe Client do
    let(:ip_address) { "1.2.3.4" }
    subject(:client) { described_class.new(ip_address) }

    describe "command length" do
      it "rejects a command line longer than the RFC permits" do
        expect(client.handle("A" * (described_class::MAX_COMMAND_LINE_LENGTH + 1)))
          .to eq "500 5.5.2 Line too long"
      end

      it "accepts a command line at the limit, which is then handled normally" do
        expect(client.handle("A" * described_class::MAX_COMMAND_LINE_LENGTH))
          .to eq "502 5.5.2 Invalid/unsupported command"
      end

      it "does not apply the command limit to message text" do
        server = create(:server)
        route = create(:route, server: server)
        address = "#{route.token}@#{Postal::Config.dns.route_domain}"

        client.handle("HELO test.example.com")
        client.handle("MAIL FROM: test@example.com")
        client.handle("RCPT TO: #{address}")

        expect(client.handle("DATA")).to eq "354 Go ahead"
        expect(client.handle("B" * 5000)).to be_nil
      end
    end

    describe "STARTTLS" do
      it "refuses starttls before the client has introduced itself" do
        expect(client.handle("STARTTLS")).to eq "503 5.5.1 STARTTLS not available now"
      end

      it "discards the session when TLS is negotiated" do
        allow(Postal::Config.smtp_server).to receive(:tls_enabled?).and_return(true)
        client.handle("EHLO test.example.com")

        expect(client.handle("STARTTLS")).to eq "220 2.0.0 Ready to start TLS"
        expect(client.state).to eq :welcome
        expect(client.helo_name).to be_nil
        expect(client.handle("MAIL FROM: test@example.com")).to eq "503 5.5.1 EHLO/HELO first please"
      end
    end

    describe "AUTH ordering" do
      it "refuses AUTH before the client has introduced itself" do
        expect(client.handle("AUTH PLAIN")).to eq "503 5.5.1 AUTH not available now"
      end

      it "refuses AUTH part-way through a transaction" do
        client.handle("HELO test.example.com")
        client.handle("MAIL FROM: test@example.com")

        expect(client.handle("AUTH PLAIN")).to eq "503 5.5.1 AUTH not available now"
      end
    end

    describe "recipients" do
      it "refuses more recipients than the limit allows" do
        server = create(:server)
        route = create(:route, server: server)
        address = "#{route.token}@#{Postal::Config.dns.route_domain}"
        allow(Postal::Config.smtp_server).to receive(:max_recipients).and_return(1)

        client.handle("HELO test.example.com")
        client.handle("MAIL FROM: test@example.com")

        expect(client.handle("RCPT TO: #{address}")).to eq "250 2.1.5 OK"
        expect(client.handle("RCPT TO: #{address}")).to eq "452 4.5.3 Too many recipients"
      end

      it "allows any number of recipients when the limit is disabled" do
        server = create(:server)
        route = create(:route, server: server)
        address = "#{route.token}@#{Postal::Config.dns.route_domain}"
        allow(Postal::Config.smtp_server).to receive(:max_recipients).and_return(0)

        client.handle("HELO test.example.com")
        client.handle("MAIL FROM: test@example.com")

        5.times do
          expect(client.handle("RCPT TO: #{address}")).to eq "250 2.1.5 OK"
        end
      end
    end

    describe "SMTP authentication attempts" do
      before do
        allow(Postal::Config.protection).to receive(:smtp_auth_attempts_limit).and_return(3)
        allow(Postal::Config.protection).to receive(:smtp_auth_attempts_period).and_return(900)
        client.handle("HELO test.example.com")
      end

      it "refuses and disconnects an address which has spent its allowance" do
        wrong = "AUTH PLAIN #{Base64.encode64("user\0wrong")}"

        3.times do
          expect(client.handle(wrong)).to eq "535 5.7.8 Invalid credential"
        end

        expect(client.handle(wrong))
          .to eq "421 4.7.0 Too many failed authentication attempts, try again later"
        expect(client.finished?).to be true
      end

      it "starts again with a full allowance once authentication succeeds" do
        credential = create(:credential, type: "SMTP")
        wrong = "AUTH PLAIN #{Base64.encode64("user\0wrong")}"

        2.times { client.handle(wrong) }
        expect(client.handle("AUTH PLAIN #{credential.to_smtp_plain}")).to match(/235 2\.7\.0 Granted for/)

        3.times do
          expect(client.handle(wrong)).to eq "535 5.7.8 Invalid credential"
        end
      end

      it "counts each address separately" do
        other = described_class.new("5.6.7.8")
        other.handle("HELO test.example.com")
        wrong = "AUTH PLAIN #{Base64.encode64("user\0wrong")}"

        3.times { client.handle(wrong) }

        expect(other.handle(wrong)).to eq "535 5.7.8 Invalid credential"
      end

      it "counts every mechanism against the same allowance" do
        # The mechanism must not be a way around the allowance. PLAIN and LOGIN
        # both pass through #authenticate and CRAM-MD5 applies the guard itself,
        # so three attempts spread across the three of them still exhaust it.
        wrong = "AUTH PLAIN #{Base64.encode64("user\0wrong")}"

        expect(client.handle(wrong)).to eq "535 5.7.8 Invalid credential"
        expect(client.handle("AUTH LOGIN")).to eq "334 VXNlcm5hbWU6"
        expect(client.handle(Base64.encode64("user"))).to eq "334 UGFzc3dvcmQ6"
        expect(client.handle(Base64.encode64("wrong"))).to eq "535 5.7.8 Invalid credential"
        expect(client.handle("AUTH CRAM-MD5")).to start_with "334 "
        expect(client.handle("bogus")).to eq "535 5.7.8 Denied"

        expect(client.handle(wrong))
          .to eq "421 4.7.0 Too many failed authentication attempts, try again later"
      end
    end

    describe "idle sessions" do
      it "expires a session which has been quiet for longer than the timeout" do
        allow(Postal::Config.smtp_server).to receive(:idle_timeout).and_return(10)

        expect(client.expired?).to be false
        expect(client.expired?(Time.now.to_i + 11)).to be true
      end

      it "never expires a session when the timeout is disabled" do
        allow(Postal::Config.smtp_server).to receive(:idle_timeout).and_return(0)

        expect(client.expired?(Time.now.to_i + 100_000)).to be false
      end

      it "counts any command as activity" do
        allow(Postal::Config.smtp_server).to receive(:idle_timeout).and_return(10)
        client.handle("NOOP")

        expect(client.expired?(Time.now.to_i + 5)).to be false
      end
    end
  end

end
