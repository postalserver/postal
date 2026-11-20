# frozen_string_literal: true

require "rails_helper"

describe Postal::MessageDB::Message do
  let(:server) { create(:server, priority: 25) }

  describe "#batch_key" do
    context "for an outgoing message" do
      it "includes the recipient domain and the server's priority" do
        message = MessageFactory.outgoing(server)
        expect(message.batch_key).to eq "outgoing-example.com-p:25"
      end

      it "is different for messages to the same domain from servers with different priorities" do
        other_server = create(:server, priority: 5)
        message = MessageFactory.outgoing(server)
        other_message = MessageFactory.outgoing(other_server)
        expect(message.batch_key).not_to eq other_message.batch_key
      end

      it "is the same for messages to the same domain from servers with the same priority" do
        other_server = create(:server, priority: 25)
        message = MessageFactory.outgoing(server)
        other_message = MessageFactory.outgoing(other_server)
        expect(message.batch_key).to eq other_message.batch_key
      end
    end

    context "for an incoming message" do
      it "does not include the server's priority" do
        message = MessageFactory.incoming(server)
        expect(message.batch_key).to start_with "incoming-"
        expect(message.batch_key).not_to include "-p:"
      end
    end
  end

  describe "#add_to_message_queue" do
    it "creates a queued message for this message with the server's priority and the message's batch key" do
      message = MessageFactory.outgoing(server)
      queued_message = message.add_to_message_queue

      expect(queued_message).to be_persisted
      expect(queued_message.server).to eq server
      expect(queued_message.message_id).to eq message.id
      expect(queued_message.domain).to eq "example.com"
      expect(queued_message.priority).to eq 25
      expect(queued_message.batch_key).to eq "outgoing-example.com-p:25"
    end
  end
end
