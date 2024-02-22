# frozen_string_literal: true

require "rails_helper"

module MessageDequeuer

  RSpec.describe OutgoingMessageProcessor do
    let(:server) { create(:server) }
    let(:state) { State.new }
    let(:logger) { TestLogger.new }
    let(:domain) { create(:domain, server: server) }
    let(:credential) { create(:credential, server: server) }
    let(:message) { MessageFactory.outgoing(server, domain: domain, credential: credential) }
    let(:queued_message) { create(:queued_message, :locked, message: message) }

    subject(:processor) { described_class.new(queued_message, logger: logger, state: state) }

    context "when the domain belonging to the message no longer exists" do
      let(:message) { MessageFactory.outgoing(server, domain: nil, credential: credential) }

      it "logs" do
        processor.process
        expect(logger).to have_logged(/message has no domain/)
      end

      it "sets the message status to HardFail" do
        processor.process
        expect(message.reload.status).to eq "HardFail"
      end

      it "creates a HardFail delivery" do
        processor.process
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "HardFail", details: /Message's domain no longer exist/i)
      end

      it "removes the queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the message has no rcpt to address" do
      before do
        message.update(rcpt_to: "")
      end

      it "logs" do
        processor.process
        expect(logger).to have_logged(/message has no 'to' address/)
      end

      it "sets the message status to HardFail" do
        processor.process
        expect(message.reload.status).to eq "HardFail"
      end

      it "creates a HardFail delivery" do
        processor.process
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "HardFail", details: /Message doesn't have an RCPT to/i)
      end

      it "removes the queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the message has a x-postal-tag header" do
      let(:message) do
        MessageFactory.outgoing(server, domain: domain) do |_msg, mail|
          mail["x-postal-tag"] = "example-tag"
        end
      end

      it "logs" do
        processor.process
        expect(logger).to have_logged(/added tag: example-tag/)
      end

      it "adds the tag to the message object" do
        processor.process
        expect(message.reload.tag).to eq("example-tag")
      end
    end

    context "when the credential says to hold the message" do
      let(:credential) { create(:credential, hold: true) }

      context "when the message was queued manually" do
        let(:queued_message) { create(:queued_message, :locked, message: message, manual: true) }

        it "does not hold the message" do
          processor.process
          deliveries = message.deliveries.find { |d| d.status == "Held" }
          expect(deliveries).to be_nil
        end
      end

      context "when the message was not queued manually" do
        it "logs" do
          processor.process
          expect(logger).to have_logged(/credential wants us to hold messages/)
        end

        it "sets the message status to Held" do
          processor.process
          expect(message.reload.status).to eq "Held"
        end

        it "creates a Held delivery" do
          processor.process
          delivery = message.deliveries.last
          expect(delivery).to have_attributes(status: "Held", details: /Credential is configured to hold all messages authenticated/i)
        end

        it "removes the queued message" do
          processor.process
          expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context "when the rcpt address is on the suppression list" do
      before do
        server.message_db.suppression_list.add(:recipient, message.rcpt_to, reason: "testing")
      end

      context "when the message was queued manually" do
        let(:queued_message) { create(:queued_message, :locked, message: message, manual: true) }

        it "does not hold the message" do
          processor.process
          deliveries = message.deliveries.find { |d| d.status == "Held" }
          expect(deliveries).to be_nil
        end
      end

      context "when the message was not queued manually" do
        it "logs" do
          processor.process
          expect(logger).to have_logged(/recipient is on the suppression list/)
        end

        it "sets the message status to Held" do
          processor.process
          expect(message.reload.status).to eq "Held"
        end

        it "creates a Held delivery" do
          processor.process
          delivery = message.deliveries.last
          expect(delivery).to have_attributes(status: "Held", details: /Recipient \(#{message.rcpt_to}\) is on the suppression list/i)
        end

        it "removes the queued message" do
          processor.process
          expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context "when the message content has not been parsed" do
      it "parses the content" do
        mocked_parser = double("Result")
        allow(mocked_parser).to receive(:actioned?).and_return(false)
        allow(mocked_parser).to receive(:tracked_links).and_return(0)
        allow(mocked_parser).to receive(:tracked_images).and_return(0)
        expect(Postal::MessageParser).to receive(:new).with(kind_of(Postal::MessageDB::Message)).and_return(mocked_parser)
        processor.process
        reloaded_message = message.reload
        expect(reloaded_message.parsed).to eq 1
        expect(reloaded_message.tracked_links).to eq 0
        expect(reloaded_message.tracked_images).to eq 0
      end
    end

    context "when the server has an outbound spam threshold configured" do
      let(:server) { create(:server, outbound_spam_threshold: 5.0) }

      it "logs" do
        processor.process
        expect(logger).to have_logged(/inspecting message/)
        expect(logger).to have_logged(/message inspected successfully/)
      end

      it "inspects the message" do
        inspection_result = double("Result", spam_score: 1.0, threat: false, threat_message: nil, spam_checks: [])
        expect(Postal::MessageInspection).to receive(:scan).and_return(inspection_result)
        processor.process
      end

      context "when the message spam score is higher than the threshold" do
        before do
          inspection_result = double("Result", spam_score: 6.0, threat: false, threat_message: nil, spam_checks: [])
          allow(Postal::MessageInspection).to receive(:scan).and_return(inspection_result)
        end

        it "logs" do
          processor.process
          expect(logger).to have_logged(/message is spam/)
        end

        it "sets the spam boolean on the message" do
          processor.process
          expect(message.reload.spam).to be true
        end

        it "sets the message status to HardFail" do
          processor.process
          expect(message.reload.status).to eq "HardFail"
        end

        it "creates a HardFail delivery" do
          processor.process
          delivery = message.deliveries.last
          expect(delivery).to have_attributes(status: "HardFail", details: /Message is likely spam. Threshold is 5.0 and the message scored 6.0/i)
        end

        it "removes the queued message" do
          processor.process
          expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context "when the server does not have a outbound spam threshold configured" do
      it "does not inspect the message" do
        expect(Postal::MessageInspection).to_not receive(:scan)
        processor.process
      end
    end

    context "when the message already has an x-postal-msgid header" do
      let(:message) do
        MessageFactory.outgoing(server, domain: domain, credential: credential) do |_, mail|
          mail["x-postal-msgid"] = "existing-id"
        end
      end

      it "does not another one" do
        processor.process
        expect(message.reload.headers["x-postal-msgid"]).to eq ["existing-id"]
      end

      it "does not add dkim headers" do
        processor.process
        expect(message.reload.headers["dkim-signature"]).to be_nil
      end
    end

    context "when the message does not have a x-postal-msgid header" do
      it "adds it" do
        processor.process
        expect(message.reload.headers["x-postal-msgid"]).to match [match(/[a-zA-Z0-9]{12}/)]
      end

      it "adds a dkim header" do
        processor.process
        expect(message.reload.headers["dkim-signature"]).to match [match(/\Av=1; a=rsa-sha256/)]
      end
    end

    context "when the server has exceeded its send limit" do
      let(:server) { create(:server, send_limit: 5) }

      before do
        5.times { server.message_db.live_stats.increment("outgoing") }
      end

      it "updates the time the limit was exceeded" do
        expect { processor.process }.to change { server.reload.send_limit_exceeded_at }.from(nil).to(kind_of(Time))
      end

      it "logs" do
        processor.process
        expect(logger).to have_logged(/server send limit has been exceeded/)
      end

      it "sets the message status to Held" do
        processor.process
        expect(message.reload.status).to eq "Held"
      end

      it "creates a Held delivery" do
        processor.process
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "Held", details: /Message held because send limit \(5\) has been reached/i)
      end

      it "removes the queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the server is approaching its send limit" do
      let(:server) { create(:server, send_limit: 10) }

      before do
        9.times { server.message_db.live_stats.increment("outgoing") }
      end

      it "updates the time the limit was being approached" do
        expect { processor.process }.to change { server.reload.send_limit_approaching_at }.from(nil).to(kind_of(Time))
      end

      it "does not set the exceeded time" do
        expect { processor.process }.to_not change { server.reload.send_limit_exceeded_at } # rubocop:disable Lint/AmbiguousBlockAssociation
      end
    end

    context "when the server is not exceeded or approaching its limit" do
      let(:server) { create(:server, :exceeded_send_limit, send_limit: 10) }

      it "clears the approaching and exceeded limits" do
        processor.process
        server.reload
        expect(server.send_limit_approaching_at).to be_nil
        expect(server.send_limit_exceeded_at).to be_nil
      end
    end

    context "when the server is in development mode" do
      let(:server) { create(:server, mode: "Development") }

      context "when the message was queued manually" do
        let(:queued_message) { create(:queued_message, :locked, message: message, manual: true) }

        it "does not hold the message" do
          processor.process
          deliveries = message.deliveries.find { |d| d.status == "Held" }
          expect(deliveries).to be_nil
        end
      end

      context "when the message was not queued manually" do
        it "logs" do
          processor.process
          expect(logger).to have_logged(/server is in development mode/)
        end

        it "sets the message status to Held" do
          processor.process
          expect(message.reload.status).to eq "Held"
        end

        it "creates a Held delivery" do
          processor.process
          delivery = message.deliveries.last
          expect(delivery).to have_attributes(status: "Held", details: /Server is in development mode/i)
        end

        it "removes the queued message" do
          processor.process
          expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context "when there are no other impediments" do
      let(:send_result) do
        SendResult.new do |r|
          r.type = "Sent"
        end
      end

      before do
        mocked_sender = double("SMTPSender")
        allow(mocked_sender).to receive(:send_message).and_return(send_result)
        allow(state).to receive(:sender_for).and_return(mocked_sender)
      end

      it "increments the live stats" do
        expect { processor.process }.to change { server.message_db.live_stats.total(60) }.from(0).to(1)
      end

      context "when there is an IP address assigned to the queued message" do
        let(:ip) { create(:ip_address) }
        let(:queued_message) { create(:queued_message, :locked, message: message, ip_address: ip) }

        it "gets a sender from the state and sends the message to it" do
          mocked_sender = double("SMTPSender")
          expect(mocked_sender).to receive(:send_message).with(queued_message.message).and_return(send_result)
          expect(state).to receive(:sender_for).with(SMTPSender, message.recipient_domain, ip).and_return(mocked_sender)

          processor.process
        end
      end

      context "when there is no IP address assigned to the queued message" do
        it "gets a sender from the state and sends the message to it" do
          mocked_sender = double("SMTPSender")
          expect(mocked_sender).to receive(:send_message).with(queued_message.message).and_return(send_result)
          expect(state).to receive(:sender_for).with(SMTPSender, message.recipient_domain, nil).and_return(mocked_sender)

          processor.process
        end
      end

      context "when the message hard fails" do
        before do
          send_result.type = "HardFail"
        end

        context "when the recipient has got no hard fails in the last 24 hours" do
          it "does not add to the suppression list" do
            processor.process
            expect(server.message_db.suppression_list.all_with_pagination(1)[:total]).to eq 0
          end
        end

        context "when the recipient has more than one hard fail in the last 24 hours" do
          before do
            2.times do
              MessageFactory.outgoing(server, domain: domain, credential: credential) do |msg|
                msg.status = "HardFail"
              end
            end
          end

          it "logs" do
            processor.process
            expect(logger).to have_logged(/added #{message.rcpt_to} to suppression list because 2 hard fails in 24 hours/i)
          end

          it "adds the recipient to the suppression list" do
            processor.process
            entry = server.message_db.suppression_list.get(:recipient, message.rcpt_to)
            expect(entry).to match hash_including(
              "address" => message.rcpt_to,
              "type" => "recipient",
              "reason" => "too many hard fails"
            )
          end
        end
      end

      context "when the message is sent manually and the recipient is on the suppression list" do
        let(:queued_message) { create(:queued_message, :locked, message: message, manual: true) }

        before do
          server.message_db.suppression_list.add(:recipient, message.rcpt_to, reason: "testing")
        end

        it "logs" do
          processor.process
          expect(logger).to have_logged(/removed #{message.rcpt_to} from suppression list/)
        end

        it "removes them from the suppression list" do
          processor.process
          expect(server.message_db.suppression_list.get(:recipient, message.rcpt_to)).to be_nil
        end

        it "adds the details to the delivery details" do
          processor.process
          delivery = message.deliveries.last
          expect(delivery.details).to include("Recipient removed from suppression list")
        end
      end

      it "creates a delivery with the appropriate details" do
        send_result.details = "Sent successfully to mx.example.com"
        processor.process
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "Sent", details: "Sent successfully to mx.example.com")
      end

      context "if the message should be retried" do
        before do
          send_result.type = "SoftFail"
          send_result.retry = true
        end

        it "logs" do
          processor.process
          expect(logger).to have_logged(/message requeued for trying later/)
        end

        it "sets the message status to SoftFail" do
          processor.process
          expect(message.reload.status).to eq "SoftFail"
        end

        it "updates the retry time on the queued message" do
          Timecop.freeze do
            retry_time = 5.minutes.from_now.change(usec: 0)
            processor.process
            expect(queued_message.reload.retry_after).to eq retry_time
          end
        end
      end

      context "if the message should not be retried" do
        it "logs" do
          processor.process
          expect(logger).to have_logged(/message processing complete/)
        end

        it "sets the message status to Sent" do
          processor.process
          expect(message.reload.status).to eq "Sent"
        end

        it "removes the queued message" do
          processor.process
          expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context "when an exception occurrs during processing" do
      before do
        smtp_sender_mock = double("SMTPSender")
        allow(SMTPSender).to receive(:new).and_return(smtp_sender_mock)
        allow(smtp_sender_mock).to receive(:start)
        allow(smtp_sender_mock).to receive(:send_message) do
          1 / 0
        end
      end

      it "logs" do
        processor.process
        expect(logger).to have_logged(/internal error: ZeroDivisionError/i)
      end

      it "creates an Error delivery" do
        processor.process
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "Error", details: /internal error/i)
      end

      it "marks the message for retrying later" do
        processor.process
        expect(queued_message.reload.retry_after).to be_present
      end
    end
  end

end
