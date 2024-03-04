# frozen_string_literal: true

require "rails_helper"

module SMTPServer

  describe Client do
    let(:ip_address) { "1.2.3.4" }
    subject(:client) { described_class.new(ip_address) }

    describe "MAIL FROM" do
      it "returns an error if no HELO is provided" do
        expect(client.handle("MAIL FROM: test@example.com")).to eq "503 EHLO/HELO first please"
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
        expect(client.handle("MAIL FROM: test@example.com")).to eq "250 OK"
        expect(client.state).to eq :mail_from_received
        expect(client.instance_variable_get("@mail_from")).to eq "test@example.com"
      end
    end
  end

end
