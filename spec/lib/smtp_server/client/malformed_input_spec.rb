# frozen_string_literal: true

require "rails_helper"

module SMTPServer

  describe Client do
    let(:ip_address) { "1.2.3.4" }
    subject(:client) { described_class.new(ip_address) }

    def welcomed
      client.handle("HELO test.example.com")
      client
    end

    def at_mail_from(mail_from = "MAIL FROM:<sender@example.com>")
      welcomed
      client.handle(mail_from)
      client
    end

    describe "commands it does not understand" do
      it "answers 502 rather than raising" do
        expect(client.handle("FROBNICATE")).to eq "502 5.5.2 Invalid/unsupported command"
      end

      it "answers an empty line with 502" do
        expect(client.handle("")).to eq "502 5.5.2 Invalid/unsupported command"
      end

      it "answers a line of whitespace with 502" do
        expect(client.handle("   ")).to eq "502 5.5.2 Invalid/unsupported command"
      end

      it "leaves the session state untouched" do
        welcomed

        client.handle("FROBNICATE")

        expect(client.state).to eq :welcomed
      end

      it "accepts its commands in any case" do
        expect(client.handle("helo test.example.com")).to eq "250 2.0.0 postal.example.com"
        expect(client.handle("mail from:<a@b.com>")).to eq "250 2.1.0 OK"
        expect(client.handle("rset")).to eq "250 2.0.0 OK"
      end

      it "tolerates a client which never sends a carriage return" do
        expect(client.handle("HELO test.example.com")).to eq "250 2.0.0 postal.example.com"
        expect(client.handle("MAIL FROM:<a@b.com>")).to eq "250 2.1.0 OK"
      end
    end

    describe "the order commands arrive in" do
      it "refuses MAIL FROM before the client has introduced itself" do
        expect(client.handle("MAIL FROM:<a@b.com>")).to eq "503 5.5.1 EHLO/HELO first please"
      end

      it "refuses DATA before there is a recipient" do
        at_mail_from

        expect(client.handle("DATA")).to eq "503 5.5.1 HELO/EHLO, MAIL FROM and RCPT TO before sending data"
      end

      it "refuses STARTTLS part-way through a transaction" do
        at_mail_from

        expect(client.handle("STARTTLS")).to eq "503 5.5.1 STARTTLS not available now"
      end

      it "empties the transaction on RSET" do
        at_mail_from
        expect(client.state).to eq :mail_from_received

        client.handle("RSET")

        expect(client.state).to eq :welcomed
        expect(client.recipients).to be_empty
      end

      it "marks the session finished on QUIT" do
        expect(client.handle("QUIT")).to eq "221 2.0.0 Closing Connection"
        expect(client.finished?).to be true
      end
    end

    describe "line length" do
      it "counts octets rather than characters" do
        # 200 two-byte characters is 400 octets, which is inside the limit even
        # though the line looks long.
        expect(client.handle("é" * 200)).to eq "502 5.5.2 Invalid/unsupported command"
      end

      it "refuses a line which is over the limit in octets even if it is short in characters" do
        expect(client.handle("é" * 300)).to eq "500 5.5.2 Line too long"
      end

      it "does not apply the limit to an AUTH continuation" do
        welcomed
        client.handle("AUTH PLAIN")

        expect(client.handle("A" * 1000)).not_to eq "500 5.5.2 Line too long"
      end
    end

    describe "the SIZE parameter" do
      let(:maximum) { Postal::Config.smtp_server.max_message_size.megabytes }

      it "accepts a size exactly at the limit" do
        welcomed

        expect(client.handle("MAIL FROM:<a@b.com> SIZE=#{maximum}")).to eq "250 2.1.0 OK"
        expect(client.state).to eq :mail_from_received
      end

      it "refuses a size one octet over the limit, leaving the session as it was" do
        welcomed

        expect(client.handle("MAIL FROM:<a@b.com> SIZE=#{maximum + 1}"))
          .to eq "552 5.3.4 Message too large (maximum size 14MB)"
        expect(client.state).to eq :welcomed
      end

      it "accepts a value which is not a number" do
        # A non-numeric SIZE coerces to zero rather than being rejected, so a
        # client which gets the syntax wrong is still allowed to send and the
        # post-DATA length check remains the backstop.
        welcomed

        expect(client.handle("MAIL FROM:<a@b.com> SIZE=abc")).to eq "250 2.1.0 OK"
      end

      it "accepts a negative value" do
        welcomed

        expect(client.handle("MAIL FROM:<a@b.com> SIZE=-1")).to eq "250 2.1.0 OK"
      end
    end

    describe "the BODY parameter" do
      it "accepts an eight-bit body in any case" do
        welcomed

        expect(client.handle("MAIL FROM:<a@b.com> BODY=8bitmime")).to eq "250 2.1.0 OK"
      end

      it "refuses an empty value" do
        welcomed

        expect(client.handle("MAIL FROM:<a@b.com> BODY=")).to eq "501 5.5.4 Unsupported BODY value"
        expect(client.state).to eq :welcomed
      end

      it "carries several parameters at once" do
        welcomed

        expect(client.handle("MAIL FROM:<a@b.com> BODY=8BITMIME SMTPUTF8")).to eq "250 2.1.0 OK"
        expect(client.state).to eq :mail_from_received
      end
    end

    describe "recipient addresses" do
      it "refuses an empty address" do
        at_mail_from

        expect(client.handle("RCPT TO:")).to eq "501 5.1.3 RCPT TO should not be empty"
      end

      it "refuses something which is not an address at all" do
        at_mail_from

        expect(client.handle("RCPT TO: not-an-address")).to eq "501 5.1.3 Invalid RCPT TO"
      end

      it "demands authentication for an address it does not host" do
        at_mail_from

        expect(client.handle("RCPT TO:<a@b.com>")).to eq "530 5.7.0 Authentication required"
      end
    end

    describe "authentication mechanisms" do
      it "answers a mechanism it does not implement with 502" do
        welcomed

        expect(client.handle("AUTH FOO")).to eq "502 5.5.2 Invalid/unsupported command"
      end

      it "refuses a PLAIN credential which is not valid base64" do
        welcomed

        expect(client.handle("AUTH PLAIN !!!!notbase64!!!!"))
          .to eq "535 5.7.8 Authentication failed - protocol error"
      end

      it "refuses an empty PLAIN continuation" do
        welcomed
        client.handle("AUTH PLAIN")

        expect(client.handle("")).to eq "535 5.7.8 Authentication failed - protocol error"
      end

      it "stays in the welcomed state after a failed attempt" do
        welcomed
        client.handle("AUTH PLAIN !!!!notbase64!!!!")

        expect(client.state).to eq :welcomed
      end

      it "refuses a LOGIN attempt whose steps are not valid base64" do
        welcomed
        expect(client.handle("AUTH LOGIN")).to eq "334 VXNlcm5hbWU6"
        expect(client.handle("!!!")).to eq "334 UGFzc3dvcmQ6"

        expect(client.handle("!!!")).to eq "535 5.7.8 Invalid credential"
      end

      it "refuses a CRAM-MD5 response which does not match any credential" do
        welcomed
        expect(client.handle("AUTH CRAM-MD5")).to start_with "334 "

        expect(client.handle("bogus")).to eq "535 5.7.8 Denied"
      end
    end

    describe "the proxy protocol" do
      subject(:client) { described_class.new(nil) }

      it "starts in the preauth state" do
        expect(client.state).to eq :preauth
      end

      it "answers a malformed PROXY line with an error rather than raising" do
        expect(client.handle("PROXY nonsense")).to eq "502 5.5.2 Proxy Error"
      end

      it "treats any other command before the PROXY line as a proxy error" do
        expect(client.handle("NOOP")).to eq "502 5.5.2 Proxy Error"
      end
    end

    describe "hostile input" do
      # Values a real client, or something pretending to be one, can send. None
      # of them may raise, and each must produce a reply (or the nil which tells
      # the reader there is nothing to say yet).
      hostile_commands = [
        "\x00\x00\x00", "\r", "\n", "\r\n", " ", "\t", ".", "..", "...",
        "MAIL", "MAIL FROM", "MAIL FROM<", "MAIL FROM:<", "MAIL FROM:<>",
        "RCPT", "RCPT TO", "RCPT TO:<", "RCPT TO:<>", "RCPT TO:<@>",
        "DATA extra", "HELO", "EHLO", "AUTH", "AUTH ", "AUTH PLAIN extra args",
        "BDAT 100", "BDAT abc LAST", "STARTTLS extra", "RSET extra", "QUIT extra",
        "MAIL FROM:<a@b.com> BODY=8BITMIME BODY=7BIT", "MAIL FROM:<a@b.com> SIZE=1 SIZE=2",
        "MAIL FROM:<#{'a' * 300}@example.com>", "RCPT TO:<#{'a' * 300}@example.com>",
        "MAIL FROM:<a@b.com>\x00", "RCPT TO:\x00@example.com", "AUTH CRAM-MD5\n",
      ].freeze

      # The same hostile values, sent by a client which has only just connected
      # and by one which is part-way through a transaction. None of them may
      # raise, and each must produce a reply, or the nil which tells the reader
      # there is nothing to say yet.
      sessions = {
        "on a fresh session" => false,
        "part-way through a transaction" => true
      }

      sessions.each do |description, mid_transaction|
        hostile_commands.each do |input|
          it "copes with #{input.inspect} #{description}" do
            at_mail_from if mid_transaction
            result = nil

            expect { result = client.handle(input) }.not_to raise_error
            expect(result.is_a?(String) || result.is_a?(Array) || result.nil?).to be true
          end
        end
      end

      it "copes with hostile input while it is receiving data" do
        server = create(:server)
        route = create(:route, server: server)
        address = "#{route.token}@#{Postal::Config.dns.route_domain}"

        welcomed
        client.handle("MAIL FROM:<a@b.com>")
        client.handle("RCPT TO: #{address}")
        expect(client.handle("DATA")).to eq "354 Go ahead"

        ["\x00" * 100, "." * 10, "\r", "..hidden", "\\", "%s%s%s", "\u0000"].each do |input|
          expect { client.handle(input) }.not_to raise_error
        end
      end
    end
  end

end
