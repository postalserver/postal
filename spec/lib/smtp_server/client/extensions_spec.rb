# frozen_string_literal: true

require "rails_helper"

module SMTPServer

  describe Client do
    let(:ip_address) { "1.2.3.4" }
    subject(:client) { described_class.new(ip_address) }

    let(:server) { create(:server) }
    let(:route) { create(:route, server: server) }
    let(:address) { "#{route.token}@#{Postal::Config.dns.route_domain}" }

    # Introduce ourselves, then open a transaction up to the point where the
    # message itself is being received.
    def open_transaction(mail_from: "MAIL FROM:<test@example.com>")
      client.handle("HELO test.example.com")
      client.handle(mail_from)
      client.handle("RCPT TO: #{address}")
      client.handle("DATA")
    end

    describe "BODY" do
      it "accepts a seven bit body" do
        client.handle("HELO test.example.com")

        expect(client.handle("MAIL FROM:<test@example.com> BODY=7BIT")).to eq "250 2.1.0 OK"
      end

      it "accepts an eight bit body" do
        client.handle("HELO test.example.com")

        expect(client.handle("MAIL FROM:<test@example.com> BODY=8BITMIME")).to eq "250 2.1.0 OK"
      end

      it "refuses a body type it cannot carry" do
        client.handle("HELO test.example.com")

        expect(client.handle("MAIL FROM:<test@example.com> BODY=BINARYMIME")).to eq "501 5.5.4 Unsupported BODY value"
      end

      it "carries eight bit octets through the data phase unchanged" do
        open_transaction(mail_from: "MAIL FROM:<test@example.com> BODY=8BITMIME")
        client.handle("Grüße aus München".dup.force_encoding("BINARY"))

        expect(client.instance_variable_get(:@data).force_encoding("UTF-8")).to include "Grüße aus München"
      end
    end

    describe "SMTPUTF8" do
      it "accepts the parameter" do
        client.handle("HELO test.example.com")

        expect(client.handle("MAIL FROM:<test@example.com> SMTPUTF8")).to eq "250 2.1.0 OK"
      end

      it "records the internationalised session in the received header" do
        open_transaction(mail_from: "MAIL FROM:<test@example.com> SMTPUTF8")

        expect(client.headers["received"].first).to include "with SMTPUTF8"
      end

      it "does not claim an internationalised session when none was requested" do
        open_transaction

        expect(client.headers["received"].first).not_to include "SMTPUTF8"
      end

      it "accepts a non-ascii address in the envelope" do
        client.handle("HELO test.example.com")
        client.handle("MAIL FROM:<test@example.com> SMTPUTF8")

        expect(client.handle("RCPT TO: <bücher@example.com>")).to eq "530 5.7.0 Authentication required"
      end
    end

    describe "PIPELINING" do
      it "answers a pipelined batch in the order the commands were sent" do
        replies = ["EHLO test.example.com", "NOOP", "RSET"].map do |command|
          client.handle(command)
        end

        expect(replies[0]).to be_an(Array)
        expect(replies[1]).to eq "250 2.0.0 OK"
        expect(replies[2]).to eq "250 2.0.0 OK"
      end
    end
  end

end
