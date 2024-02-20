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
      let(:domain) { create(:domain, server: server) }
      let(:message) { MessageFactory.outgoing(server, domain: domain) }
      let(:queued_message) { create(:queued_message, :locked, message: message) }
      let(:send_result) { Postal::SendResult.new }

      before do
        smtp_sender_mock = double("SMTPSender")
        allow(Postal::SMTPSender).to receive(:new).and_return(smtp_sender_mock)
        allow(smtp_sender_mock).to receive(:start)
        allow(smtp_sender_mock).to receive(:finish)
        allow(smtp_sender_mock).to receive(:send_message).and_return(send_result)
      end

      before do
        # Create 2 extra messages which are similar to the original
        @message2 = MessageFactory.outgoing(server, domain: domain)
        @queued_message2 = create(:queued_message, message: @message2)
        @message3 = MessageFactory.outgoing(server, domain: domain)
        @queued_message3 = create(:queued_message, message: @message3)
      end

      it "logs" do
        service.call
        expect(logger).to have_logged(/found 2 associated messages/)
      end

      it "sends processes each message" do
        allow(service).to receive(:process_message).and_call_original
        service.call
        expect(service).to have_received(:process_message).with(queued_message)
        expect(service).to have_received(:process_message).with(@queued_message2)
        expect(service).to have_received(:process_message).with(@queued_message3)
      end

      context "when there is a connect error" do
        before do
          send_result.type = "SoftFail"
          send_result.connect_error = true
          send_result.details = "Connection Error"
          send_result.retry = true
        end

        it "uses the same result for subsequent messages" do
          service.call
          expect(Postal::SMTPSender).to have_received(:new).once
          expect(message.reload.status).to eq "SoftFail"
          expect(@message2.reload.status).to eq "SoftFail"
          expect(@message3.reload.status).to eq "SoftFail"
        end
      end

      context "when the backend message of a sub-message has been removed" do
        before do
          @message2.delete
        end

        it "logs" do
          service.call
          expect(logger).to have_logged(/unqueueing because backend message has been removed/)
        end

        it "removes the queued message for that message" do
          service.call
          expect { @queued_message2.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end
