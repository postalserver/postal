# frozen_string_literal: true

require "rails_helper"

module SMTPServer

  describe Client do
    let(:ip_address) { "1.2.3.4" }
    subject(:client) { described_class.new(ip_address) }

    describe "DATA" do
      it "returns an error if no helo" do
        expect(client.handle("DATA")).to eq "503 HELO/EHLO, MAIL FROM and RCPT TO before sending data"
      end

      it "returns an error if no mail from" do
        client.handle("HELO test.example.com")
        expect(client.handle("DATA")).to eq "503 HELO/EHLO, MAIL FROM and RCPT TO before sending data"
      end

      it "returns an error if no rcpt to" do
        client.handle("HELO test.example.com")
        client.handle("MAIL FROM: test@example.com")
        expect(client.handle("DATA")).to eq "503 HELO/EHLO, MAIL FROM and RCPT TO before sending data"
      end

      it "returns go ahead" do
        route = create(:route)
        client.handle("HELO test.example.com")
        client.handle("MAIL FROM: test@test.com")
        client.handle("RCPT TO: #{route.name}@#{route.domain.name}")
        expect(client.handle("DATA")).to eq "354 Go ahead"
      end

      it "adds a received header for itself" do
        route = create(:route)
        client.handle("HELO test.example.com")
        client.handle("MAIL FROM: test@test.com")
        client.handle("RCPT TO: #{route.name}@#{route.domain.name}")
        Timecop.freeze do
          client.handle("DATA")
          expect(client.headers["received"]).to include "from test.example.com (1.2.3.4 [1.2.3.4]) by #{Postal::Config.postal.smtp_hostname} with SMTP; #{Time.now.utc.rfc2822}"
        end
      end

      describe "subsequent commands" do
        let(:route) { create(:route) }
        before do
          client.handle("HELO test.example.com")
          client.handle("MAIL FROM: test@test.com")
          client.handle("RCPT TO: #{route.name}@#{route.domain.name}")
        end

        it "logs headers" do
          client.handle("DATA")
          client.handle("Subject: Test")
          client.handle("From: test@test.com")
          client.handle("To: test1@example.com")
          client.handle("To: test2@example.com")
          client.handle("X-Something: abcdef1234")
          client.handle("X-Multiline: 1234")
          client.handle("             4567")
          expect(client.headers["subject"]).to eq ["Test"]
          expect(client.headers["from"]).to eq ["test@test.com"]
          expect(client.headers["to"]).to eq ["test1@example.com", "test2@example.com"]
          expect(client.headers["x-something"]).to eq ["abcdef1234"]
          expect(client.headers["x-multiline"]).to eq ["1234             4567"]
        end

        it "logs content" do
          Timecop.freeze do
            client.handle("DATA")
            client.handle("Subject: Test")
            client.handle("")
            client.handle("This is some content for the message.")
            client.handle("It will keep going.")
            expect(client.instance_variable_get("@data")).to eq <<~DATA
              Received: from test.example.com (1.2.3.4 [1.2.3.4]) by #{Postal::Config.postal.smtp_hostname} with SMTP; #{Time.now.utc.rfc2822}\r
              Subject: Test\r
              \r
              This is some content for the message.\r
              It will keep going.\r
            DATA
          end
        end
      end
    end
  end

end
