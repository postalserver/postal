# frozen_string_literal: true

require "rails_helper"

module MessageDequeuer

  RSpec.describe SingleMessageProcessor do
    let(:server) { create(:server) }
    let(:state) { State.new }
    let(:logger) { TestLogger.new }
    let(:route) { create(:route, server: server) }
    let(:message) { MessageFactory.incoming(server, route: route) }
    let(:queued_message) { create(:queued_message, :locked, message: message) }

    subject(:processor) { described_class.new(queued_message, logger: logger, state: state) }

    context "when the server is suspended" do
      before do
        allow(queued_message.server).to receive(:suspended?).and_return(true)
      end

      it "logs" do
        processor.process
        expect(logger).to have_logged(/server is suspended/)
      end

      it "sets the message status to Held" do
        processor.process
        expect(message.reload.status).to eq "Held"
      end

      it "creates a Held delivery" do
        processor.process
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "Held", details: /server has been suspended/i)
      end

      it "removes the queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the number of attempts is more than the maximum" do
      let(:queued_message) { create(:queued_message, :locked, message: message, attempts: Postal::Config.postal.default_maximum_delivery_attempts + 1) }

      it "logs" do
        processor.process
        expect(logger).to have_logged(/message has reached maximum number of attempts/)
      end

      it "sends a bounce to the sender" do
        expect(BounceMessage).to receive(:new).with(server, queued_message.message)
        processor.process
      end

      it "sets the message status to HardFail" do
        processor.process
        expect(message.reload.status).to eq "HardFail"
      end

      it "creates a HardFail delivery" do
        processor.process
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "HardFail", details: /maximum number of delivery attempts.*bounce sent to sender/i)
      end

      it "removes the queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the message raw data has been removed" do
      before do
        message.raw_table = nil
        message.save
      end

      it "logs" do
        processor.process
        expect(logger).to have_logged(/raw message has been removed/)
      end

      it "sets the message status to HardFail" do
        processor.process
        expect(message.reload.status).to eq "HardFail"
      end

      it "creates a HardFail delivery" do
        processor.process
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "HardFail", details: /Raw message has been removed/i)
      end

      it "removes the queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the message is incoming" do
      it "calls the incoming message processor" do
        expect(IncomingMessageProcessor).to receive(:new).with(queued_message,
                                                               logger: logger,
                                                               state: processor.state)
        processor.process
      end

      it "does not call the outgoing message processor" do
        expect(OutgoingMessageProcessor).to_not receive(:process)
        processor.process
      end
    end

    context "when the message is outgoing" do
      let(:message) { MessageFactory.outgoing(server) }

      it "calls the outgoing message processor" do
        expect(OutgoingMessageProcessor).to receive(:process).with(queued_message,
                                                                   logger: logger,
                                                                   state: processor.state)

        processor.process
      end

      it "does not call the incoming message processor" do
        expect(IncomingMessageProcessor).to_not receive(:process)
        processor.process
      end
    end
  end

end
