# frozen_string_literal: true

require "rails_helper"

RSpec.describe UnqueueMessageService do
  let(:server) { create(:server) }
  let(:logger) { TestLogger.new }
  let(:send_result) do
    Postal::SendResult.new do |r|
      r.type = "Sent"
    end
  end
  subject(:service) { described_class.new(queued_message: queued_message, logger: logger) }

  # We're going to, for now, just stop the SMTP sender from doing anything here because
  # we don't want to leak out of this test in to the real world.
  before do
    smtp_sender_mock = double("SMTPSender")
    allow(Postal::SMTPSender).to receive(:new).and_return(smtp_sender_mock)
    allow(smtp_sender_mock).to receive(:start)
    allow(smtp_sender_mock).to receive(:finish)
    allow(smtp_sender_mock).to receive(:send_message).and_return(send_result)
  end

  context "for an outgoing message" do
    let(:domain) { create(:domain, server: server) }
    let(:credential) { create(:credential, server: server) }
    let(:message) { MessageFactory.outgoing(server, domain: domain, credential: credential) }
    let(:queued_message) { create(:queued_message, :locked, message: message) }

    context "when the server is suspended" do
      let(:server) { create(:server, :suspended) }

      it "logs" do
        service.call
        expect(logger).to have_logged(/server is suspended/)
      end

      it "sets the message status to Held" do
        service.call
        expect(message.reload.status).to eq "Held"
      end

      it "creates a Hold delivery" do
        service.call
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "Held", details: /server has been suspended/i)
      end

      it "removes the queued message" do
        service.call
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the number of attempts is more than the maximum" do
      let(:queued_message) { create(:queued_message, :locked, message: message, attempts: Postal.config.general.maximum_delivery_attempts + 1) }

      it "logs" do
        service.call
        expect(logger).to have_logged(/message has reached maximum number of attempts/)
      end

      it "adds the recipient to the suppression list and logs this" do
        Timecop.freeze do
          service.call
          entry = server.message_db.suppression_list.get(:recipient, message.rcpt_to)
          expect(entry).to match hash_including(
            "address" => message.rcpt_to,
            "type" => "recipient",
            "reason" => "too many soft fails"
          )
        end
      end

      it "sets the message status to Held" do
        service.call
        expect(message.reload.status).to eq "HardFail"
      end

      it "creates a HardFail delivery" do
        service.call
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "HardFail", details: /maximum number of delivery attempts.*added [\w.@]+ to suppression list/i)
      end

      it "removes the queued message" do
        service.call
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the message raw data has been removed" do
      before do
        message.raw_table = nil
        message.save
      end

      it "logs" do
        service.call
        expect(logger).to have_logged(/raw message has been removed/)
      end

      it "sets the message status to Held" do
        service.call
        expect(message.reload.status).to eq "HardFail"
      end

      it "creates a HardFail delivery" do
        service.call
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "HardFail", details: /Raw message has been removed/i)
      end

      it "removes the queued message" do
        service.call
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the domain belonging to the message no longer exists" do
      before do
        domain.destroy
      end

      it "logs" do
        service.call
        expect(logger).to have_logged(/message has no domain/)
      end

      it "sets the message status to HardFail" do
        service.call
        expect(message.reload.status).to eq "HardFail"
      end

      it "creates a HardFail delivery" do
        service.call
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "HardFail", details: /Message's domain no longer exist/i)
      end

      it "removes the queued message" do
        service.call
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the message has no rcpt to address" do
      before do
        message.update(rcpt_to: "")
      end

      it "logs" do
        service.call
        expect(logger).to have_logged(/message has no 'to' address/)
      end

      it "sets the message status to HardFail" do
        service.call
        expect(message.reload.status).to eq "HardFail"
      end

      it "creates a HardFail delivery" do
        service.call
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "HardFail", details: /Message doesn't have an RCPT to/i)
      end

      it "removes the queued message" do
        service.call
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
        service.call
        expect(logger).to have_logged(/added tag: example-tag/)
      end

      it "adds the tag to the message object" do
        service.call
        expect(message.reload.tag).to eq("example-tag")
      end
    end

    context "when the credential says to hold the message" do
      let(:credential) { create(:credential, hold: true) }

      context "when the message was queued manually" do
        let(:queued_message) { create(:queued_message, :locked, message: message, manual: true) }

        it "does not hold the message" do
          service.call
          deliveries = message.deliveries.find { |d| d.status == "Held" }
          expect(deliveries).to be_nil
        end
      end

      context "when the message was not queued manually" do
        it "logs" do
          service.call
          expect(logger).to have_logged(/credential wants us to hold messages/)
        end

        it "sets the message status to Held" do
          service.call
          expect(message.reload.status).to eq "Held"
        end

        it "creates a Held delivery" do
          service.call
          delivery = message.deliveries.last
          expect(delivery).to have_attributes(status: "Held", details: /Credential is configured to hold all messages authenticated/i)
        end

        it "removes the queued message" do
          service.call
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
          service.call
          deliveries = message.deliveries.find { |d| d.status == "Held" }
          expect(deliveries).to be_nil
        end
      end

      context "when the message was not queued manually" do
        it "logs" do
          service.call
          expect(logger).to have_logged(/recipient is on the suppression list/)
        end

        it "sets the message status to Held" do
          service.call
          expect(message.reload.status).to eq "Held"
        end

        it "creates a Held delivery" do
          service.call
          delivery = message.deliveries.last
          expect(delivery).to have_attributes(status: "Held", details: /Recipient \(#{message.rcpt_to}\) is on the suppression list/i)
        end

        it "removes the queued message" do
          service.call
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
        service.call
        reloaded_message = message.reload
        expect(reloaded_message.parsed).to eq 1
        expect(reloaded_message.tracked_links).to eq 0
        expect(reloaded_message.tracked_images).to eq 0
      end
    end

    context "when the server has an outbound spam threshold configured" do
      let(:server) { create(:server, outbound_spam_threshold: 5.0) }

      it "logs" do
        service.call
        expect(logger).to have_logged(/inspecting message/)
        expect(logger).to have_logged(/message inspected successfully/)
      end

      it "inspects the message" do
        inspection_result = double("Result", spam_score: 1.0, threat: false, threat_message: nil, spam_checks: [])
        expect(Postal::MessageInspection).to receive(:scan).and_return(inspection_result)
        service.call
      end

      context "when the message spam score is higher than the threshold" do
        before do
          inspection_result = double("Result", spam_score: 6.0, threat: false, threat_message: nil, spam_checks: [])
          allow(Postal::MessageInspection).to receive(:scan).and_return(inspection_result)
        end

        it "logs" do
          service.call
          expect(logger).to have_logged(/message is spam/)
        end

        it "sets the spam boolean on the message" do
          service.call
          expect(message.reload.spam).to be true
        end

        it "sets the message status to HardFail" do
          service.call
          expect(message.reload.status).to eq "HardFail"
        end

        it "creates a HardFail delivery" do
          service.call
          delivery = message.deliveries.last
          expect(delivery).to have_attributes(status: "HardFail", details: /Message is likely spam. Threshold is 5.0 and the message scored 6.0/i)
        end

        it "removes the queued message" do
          service.call
          expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context "when the server does not have a outbound spam threshold configured" do
      it "does not inspect the message" do
        expect(Postal::MessageInspection).to_not receive(:scan)
        service.call
      end
    end

    context "when the message already has an x-postal-msgid header" do
      let(:message) do
        MessageFactory.outgoing(server, domain: domain, credential: credential) do |_, mail|
          mail["x-postal-msgid"] = "existing-id"
        end
      end

      it "does not another one" do
        service.call
        expect(message.reload.headers["x-postal-msgid"]).to eq ["existing-id"]
      end

      it "does not add dkim headers" do
        service.call
        expect(message.reload.headers["dkim-signature"]).to be_nil
      end
    end

    context "when the message does not have a x-postal-msgid header" do
      it "adds it" do
        service.call
        expect(message.reload.headers["x-postal-msgid"]).to match [match(/[a-zA-Z0-9]{12}/)]
      end

      it "adds a dkim header" do
        service.call
        expect(message.reload.headers["dkim-signature"]).to match [match(/\Av=1; a=rsa-sha256/)]
      end
    end

    context "when the server has exceeded its send limit" do
      let(:server) { create(:server, send_limit: 5) }

      before do
        5.times { server.message_db.live_stats.increment("outgoing") }
      end

      it "updates the time the limit was exceeded" do
        expect { service.call }.to change { server.reload.send_limit_exceeded_at }.from(nil).to(kind_of(Time))
      end

      it "logs" do
        service.call
        expect(logger).to have_logged(/server send limit has been exceeded/)
      end

      it "sets the message status to Held" do
        service.call
        expect(message.reload.status).to eq "Held"
      end

      it "creates a Held delivery" do
        service.call
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "Held", details: /Message held because send limit \(5\) has been reached/i)
      end

      it "removes the queued message" do
        service.call
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the server is approaching its send limit" do
      let(:server) { create(:server, send_limit: 10) }

      before do
        9.times { server.message_db.live_stats.increment("outgoing") }
      end

      it "updates the time the limit was being approached" do
        expect { service.call }.to change { server.reload.send_limit_approaching_at }.from(nil).to(kind_of(Time))
      end

      it "does not set the exceeded time" do
        expect { service.call }.to_not change { server.reload.send_limit_exceeded_at } # rubocop:disable Lint/AmbiguousBlockAssociation
      end
    end

    context "when the server is not exceeded or approaching its limit" do
      let(:server) { create(:server, :exceeded_send_limit, send_limit: 10) }

      it "clears the approaching and exceeded limits" do
        service.call
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
          service.call
          deliveries = message.deliveries.find { |d| d.status == "Held" }
          expect(deliveries).to be_nil
        end
      end

      context "when the message was not queued manually" do
        it "logs" do
          service.call
          expect(logger).to have_logged(/server is in development mode/)
        end

        it "sets the message status to Held" do
          service.call
          expect(message.reload.status).to eq "Held"
        end

        it "creates a Held delivery" do
          service.call
          delivery = message.deliveries.last
          expect(delivery).to have_attributes(status: "Held", details: /Server is in development mode/i)
        end

        it "removes the queued message" do
          service.call
          expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context "when there are no other impediments" do
      it "increments the live stats" do
        expect { service.call }.to change { server.message_db.live_stats.total(60) }.from(0).to(1)
      end

      context "when there is an IP address assigned to the queued message" do
        let(:ip) { create(:ip_address) }
        let(:queued_message) { create(:queued_message, :locked, message: message, ip_address: ip) }

        it "sends the message to the SMTP sender with the IP" do
          service.call
          expect(Postal::SMTPSender).to have_received(:new).with(message.recipient_domain, ip)
        end
      end

      context "when there is no IP address assigned to the queued message" do
        it "sends the message to the SMTP sender without an IP" do
          service.call
          expect(Postal::SMTPSender).to have_received(:new).with(message.recipient_domain, nil)
        end
      end

      context "when the message hard fails" do
        before do
          send_result.type = "HardFail"
        end

        context "when the recipient has got no hard fails in the last 24 hours" do
          it "does not add to the suppression list" do
            service.call
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
            service.call
            expect(logger).to have_logged(/added #{message.rcpt_to} to suppression list because 2 hard fails in 24 hours/i)
          end

          it "adds the recipient to the suppression list" do
            service.call
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
          service.call
          expect(logger).to have_logged(/removed #{message.rcpt_to} from suppression list/)
        end

        it "removes them from the suppression list" do
          service.call
          expect(server.message_db.suppression_list.get(:recipient, message.rcpt_to)).to be_nil
        end

        it "adds the details to the result details" do
          service.call
          expect(send_result.details).to include("Recipient removed from suppression list")
        end
      end

      it "creates a delivery with the appropriate details" do
        send_result.details = "Sent successfully to mx.example.com"
        service.call
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "Sent", details: "Sent successfully to mx.example.com")
      end

      context "if the message should be retried" do
        before do
          send_result.type = "SoftFail"
          send_result.retry = true
        end

        it "logs" do
          service.call
          expect(logger).to have_logged(/message requeued for trying later/)
        end

        it "sets the message status to SoftFail" do
          service.call
          expect(message.reload.status).to eq "SoftFail"
        end

        it "updates the retry time on the queued message" do
          Timecop.freeze do
            retry_time = 5.minutes.from_now.change(usec: 0)
            service.call
            expect(queued_message.reload.retry_after).to eq retry_time
          end
        end
      end

      context "if the message should not be retried" do
        it "logs" do
          service.call
          expect(logger).to have_logged(/message processing complete/)
        end

        it "sets the message status to Sent" do
          service.call
          expect(message.reload.status).to eq "Sent"
        end

        it "removes the queued message" do
          service.call
          expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end
