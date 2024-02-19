# frozen_string_literal: true

require "rails_helper"

RSpec.describe UnqueueMessageService do
  let(:server) { create(:server) }
  let(:logger) { TestLogger.new }
  let(:queued_message) { create(:queued_message, server: server) }
  subject(:service) { described_class.new(queued_message: queued_message, logger: logger) }

  describe "#call" do
    context "when the backend message does not exist" do
      it "deletes the queued message" do
        service.call
        expect(logger).to have_logged(/unqueue because backend message has been removed/)
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the message is not ready for processing" do
      let(:message) { MessageFactory.outgoing(server) }
      let(:queued_message) { create(:queued_message, :retry_in_future, message: message) }

      it "does not do anything" do
        service.call
        expect(logger).to have_logged(/skipping because message isn't ready for processing/)
      end
    end

    context "when there are other messages to batch with this one" do
      context "when the backend message of a sub-message has been removed" do
        it "removes the queued message for that message"
      end
    end
  end
end
