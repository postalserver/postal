# frozen_string_literal: true

require "rails_helper"

module SMTPServer

  describe Client do
    let(:ip_address) { "1.2.3.4" }
    subject(:client) { described_class.new(ip_address) }

    describe "MAIL FROM" do
      it "returns an error if no HELO is provided" do
        expect(client.handle("MAIL FROM: test@example.com")).to eq "503 5.5.1 EHLO/HELO first please"
        expect(client.state).to eq :welcome
      end

      it "resets the transaction when called" do
        expect(client).to receive(:transaction_reset).and_call_original.at_least(3).times
        client.handle("HELO test.example.com")
        client.handle("MAIL FROM: test@example.com")
        client.handle("MAIL FROM: test2@example.com")
      end

      it "sets the mail from address" do
        client.handle("HELO test.example.com")
        expect(client.handle("MAIL FROM: test@example.com")).to eq "250 2.1.0 OK"
        expect(client.state).to eq :mail_from_received
        expect(client.instance_variable_get("@mail_from")).to eq "test@example.com"
      end

      it "accepts a size declaration within the limit and ignores it in the address" do
        client.handle("HELO test.example.com")
        expect(client.handle("MAIL FROM:<test@example.com> SIZE=100")).to eq "250 2.1.0 OK"
        expect(client.instance_variable_get("@mail_from")).to eq "test@example.com"
      end

      it "refuses a size declaration larger than the limit before the message is sent" do
        client.handle("HELO test.example.com")
        declared = Postal::Config.smtp_server.max_message_size.megabytes.to_i + 1
        expect(client.handle("MAIL FROM:<test@example.com> SIZE=#{declared}"))
          .to eq "552 5.3.4 Message too large (maximum size #{Postal::Config.smtp_server.max_message_size}MB)"
        expect(client.state).to eq :welcomed
      end
    end
  end

end
