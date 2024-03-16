# frozen_string_literal: true

require "rails_helper"

module MessageDequeuer

  RSpec.describe InitialProcessor do
    let(:server) { create(:server) }
    let(:logger) { TestLogger.new }
    let(:route) { create(:route, server: server) }
    let(:message) { MessageFactory.incoming(server, route: route) }
    let(:queued_message) { create(:queued_message, :locked, message: message) }

    subject(:processor) { described_class.new(queued_message, logger: logger) }

    it "has state when not given any" do
      expect(processor.state).to be_a State
    end

    context "when associated message does not exist" do
      let(:queued_message) { create(:queued_message, :locked, message_id: 12_345) }

      it "logs" do
        processor.process
        expect(logger).to have_logged(/unqueue because backend message has been removed/)
      end

      it "removes from queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the queued message is not ready for processing" do
      let(:queued_message) { create(:queued_message, :locked, message: message, retry_after: 1.hour.from_now) }

      it "logs" do
        processor.process
        expect(logger).to have_logged(/skipping because message isn't ready for processing/)
      end

      it "unlocks and keeps the queued message" do
        processor.process
        expect(queued_message.reload).to_not be_locked
      end
    end

    context "when there are no other batchable messages" do
      it "calls the single message processor for the initial message" do
        expect(SingleMessageProcessor).to receive(:process).with(queued_message,
                                                                 logger: logger,
                                                                 state: processor.state)
        processor.process
      end
    end

    context "when there are batchable messages" do
      before do
        @message2 = MessageFactory.incoming(server, route: route)
        @queued_message2 = create(:queued_message, message: @message2)
        @message3 = MessageFactory.incoming(server, route: route)
        @queued_message3 = create(:queued_message, message: @message3)
      end

      context "when postal.batch_queued_messages is enabled" do
        it "calls the single message process for the initial message and all batchable messages" do
          [queued_message, @queued_message2, @queued_message3].each do |msg|
            expect(SingleMessageProcessor).to receive(:process).with(msg,
                                                                     logger: logger,
                                                                     state: processor.state)
          end
          processor.process
        end
      end

      context "when postal.batch_queued_messages is disabled" do
        before do
          allow(Postal::Config.postal).to receive(:batch_queued_messages?) { false }
        end

        it "does not call the single message process more than once" do
          expect(SingleMessageProcessor).to receive(:process).once.with(queued_message,
                                                                        logger: logger,
                                                                        state: processor.state)
          processor.process
        end
      end
    end

    context "when an error occurs while finding batchable messages" do
      before do
        allow(queued_message).to receive(:batchable_messages) { 1 / 0 }
      end

      it "unlocks the queued message and raises the error" do
        expect { processor.process }.to raise_error(ZeroDivisionError)
        expect(queued_message.reload).to_not be_locked
      end
    end

    context "when finished" do
      it "notifies the state that processing is complete" do
        expect(processor.state).to receive(:finished)
        processor.process
      end
    end
  end

end
