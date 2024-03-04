# frozen_string_literal: true

require "rails_helper"

module MessageDequeuer

  RSpec.describe State do
    subject(:state) { described_class.new }

    describe "#send_result" do
      it "can be get and set" do
        result = instance_double(SendResult)
        state.send_result = result
        expect(state.send_result).to be result
      end
    end

    describe "#sender_for" do
      it "returns a instance of the given sender initialized with the args" do
        sender = state.sender_for(HTTPSender, "1234")
        expect(sender).to be_a HTTPSender
      end

      it "returns a cached sender on subsequent calls" do
        sender = state.sender_for(HTTPSender, "1234")
        expect(state.sender_for(HTTPSender, "1234")).to be sender
      end
    end

    describe "#finished" do
      it "calls finish on all cached senders" do
        sender1 = state.sender_for(HTTPSender, "1234")
        sender2 = state.sender_for(HTTPSender, "4444")
        expect(sender1).to receive(:finish)
        expect(sender2).to receive(:finish)

        state.finished
      end
    end
  end

end
