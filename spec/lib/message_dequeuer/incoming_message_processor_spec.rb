# frozen_string_literal: true

require "rails_helper"

module MessageDequeuer

  RSpec.describe IncomingMessageProcessor do
    let(:server) { create(:server) }
    let(:state) { State.new }
    let(:logger) { TestLogger.new }
    let(:route) { create(:route, server: server) }
    let(:message) { MessageFactory.incoming(server, route: route) }
    let(:queued_message) { create(:queued_message, :locked, message: message) }

    subject(:processor) { described_class.new(queued_message, logger: logger, state: state) }

    context "when the message was a bounce but there's no return path for it" do
      let(:message) do
        MessageFactory.incoming(server) do |msg|
          msg.bounce = true
        end
      end

      it "logs" do
        processor.process
        expect(logger).to have_logged(/no source messages found, hard failing/)
      end

      it "sets the message status to HardFail" do
        processor.process
        expect(message.reload.status).to eq "HardFail"
      end

      it "creates a HardFail delivery" do
        processor.process
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "HardFail", details: /was a bounce but we couldn't link it with any outgoing message/i)
      end

      it "removes the queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the message is a bounce for an existing message" do
      let(:existing_message) { MessageFactory.outgoing(server) }

      let(:message) do
        MessageFactory.incoming(server) do |msg, mail|
          msg.bounce = true
          mail["X-Postal-MsgID"] = existing_message.token
        end
      end

      it "logs" do
        processor.process
        expect(logger).to have_logged(/message is a bounce/)
      end

      it "adds the original message as the bounce ID for the received message" do
        processor.process
        expect(message.reload.bounce_for_id).to eq existing_message.id
      end

      it "sets the received message status to Processed" do
        processor.process
        expect(message.reload.status).to eq "Processed"
      end

      it "creates a Processed delivery on the received message" do
        processor.process
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "Processed", details: /This has been detected as a bounce message for <msg:#{existing_message.id}>/i)
      end

      it "sets the existing message status to Bounced" do
        processor.process
        expect(existing_message.reload.status).to eq "Bounced"
      end

      it "creates a Bounced delivery on the original message" do
        processor.process
        delivery = existing_message.deliveries.last
        expect(delivery).to have_attributes(status: "Bounced", details: /received a bounce message for this e-mail. See <msg:#{message.id}> for/i)
      end

      it "triggers a MessageBounced webhook event" do
        expect(WebhookRequest).to receive(:trigger).with(server, "MessageBounced", {
          original_message: kind_of(Hash),
          bounce: kind_of(Hash)
        })
        processor.process
      end

      it "removes the queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the message is not a bounce" do
      it "increments the stats for the server" do
        expect { processor.process }.to change { server.message_db.live_stats.total(5) }.by(1)
      end

      it "inspects the message and adds headers" do
        expect { processor.process }.to change { message.reload.inspected }.from(false).to(true)
        new_message = message.reload
        expect(new_message.headers).to match hash_including(
          "x-postal-spam" => ["no"],
          "x-postal-spam-threshold" => ["5.0"],
          "x-postal-threat" => ["no"]
        )
      end

      it "marks the message as spam if the spam score is higher than the server threshold" do
        inspection_result = double("Result", spam_score: server.spam_threshold + 1, threat: false, threat_message: nil, spam_checks: [])
        allow(Postal::MessageInspection).to receive(:scan).and_return(inspection_result)
        processor.process
        expect(message.reload.spam).to be true
      end
    end

    context "when the message has a spam score greater than the server's spam failure threshold" do
      before do
        inspection_result = double("Result", spam_score: 100, threat: false, threat_message: nil, spam_checks: [])
        allow(Postal::MessageInspection).to receive(:scan).and_return(inspection_result)
      end

      it "logs" do
        processor.process
        expect(logger).to have_logged(/message has a spam score higher than the server's maxmimum/)
      end

      it "sets the message status to HardFail" do
        processor.process
        expect(message.reload.status).to eq "HardFail"
      end

      it "creates a HardFail delivery" do
        processor.process
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "HardFail", details: /spam score is higher than the failure threshold for this server/i)
      end

      it "removes the queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the server mode is Development and the message was not manually queued" do
      before do
        server.update!(mode: "Development")
      end

      after do
        server.update!(mode: "Live")
      end

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
        expect(delivery).to have_attributes(status: "Held", details: /server is in development mode/i)
      end

      it "removes the queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when there is no route for the incoming message" do
      let(:route) { nil }

      it "logs" do
        processor.process
        expect(logger).to have_logged(/no route and\/or endpoint available for processing/i)
      end

      it "sets the message status to HardFail" do
        processor.process
        expect(message.reload.status).to eq "HardFail"
      end

      it "creates a HardFail delivery" do
        processor.process
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "HardFail", details: /does not have a route and\/or endpoint available/i)
      end

      it "removes the queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the route's spam mode is Quarantine, the message is spam and not manually queued" do
      let(:route) { create(:route, server: server, spam_mode: "Quarantine") }

      before do
        inspection_result = double("Result", spam_score: server.spam_threshold + 1, threat: false, threat_message: nil, spam_checks: [])
        allow(Postal::MessageInspection).to receive(:scan).and_return(inspection_result)
      end

      it "logs" do
        processor.process
        expect(logger).to have_logged(/message is spam and route says to quarantine spam message/i)
      end

      it "sets the message status to Held" do
        processor.process
        expect(message.reload.status).to eq "Held"
      end

      it "creates a Held delivery" do
        processor.process
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "Held", details: /message placed into quarantine/i)
      end

      it "removes the queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the route's spam mode is Fail, the message is spam and not manually queued" do
      let(:route) { create(:route, server: server, spam_mode: "Fail") }

      before do
        inspection_result = double("Result", spam_score: server.spam_threshold + 1, threat: false, threat_message: nil, spam_checks: [])
        allow(Postal::MessageInspection).to receive(:scan).and_return(inspection_result)
      end

      it "logs" do
        processor.process
        expect(logger).to have_logged(/message is spam and route says to fail spam message/i)
      end

      it "sets the message status to HardFail" do
        processor.process
        expect(message.reload.status).to eq "HardFail"
      end

      it "creates a HardFail delivery" do
        processor.process
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "HardFail", details: /message is spam and the route specifies it should be failed/i)
      end

      it "removes the queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the route's mode is Accept" do
      it "logs" do
        processor.process
        expect(logger).to have_logged(/route says to accept without endpoint/i)
      end

      it "sets the message status to Processed" do
        processor.process
        expect(message.reload.status).to eq "Processed"
      end

      it "creates a Processed delivery" do
        processor.process
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "Processed", details: /message has been accepted but not sent to any endpoints/i)
      end

      it "removes the queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the route's mode is Hold" do
      let(:route) { create(:route, server: server, mode: "Hold") }

      context "when the message was queued manually" do
        let(:queued_message) { create(:queued_message, :locked, server: server, message: message, manual: true) }

        it "logs" do
          processor.process
          expect(logger).to have_logged(/route says to hold and message was queued manually/i)
        end

        it "sets the message status to Processed" do
          processor.process
          expect(message.reload.status).to eq "Processed"
        end

        it "creates a Processed delivery" do
          processor.process
          delivery = message.deliveries.last
          expect(delivery).to have_attributes(status: "Processed", details: /message has been processed/i)
        end

        it "removes the queued message" do
          processor.process
          expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context "when the message was not queued manually" do
        let(:queued_message) { create(:queued_message, :locked, server: server, message: message, manual: false) }

        it "logs" do
          processor.process
          expect(logger).to have_logged(/route says to hold, marking as held/i)
        end

        it "sets the message status to Held" do
          processor.process
          expect(message.reload.status).to eq "Held"
        end

        it "creates a Held delivery" do
          processor.process
          delivery = message.deliveries.last
          expect(delivery).to have_attributes(status: "Held", details: /message has been accepted but not sent to any endpoints/i)
        end

        it "removes the queued message" do
          processor.process
          expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context "when the route's mode is Bounce" do
      let(:route) { create(:route, server: server, mode: "Bounce") }

      it "logs" do
        processor.process
        expect(logger).to have_logged(/route says to bounce/i)
      end

      it "sends a bounce" do
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
        expect(delivery).to have_attributes(status: "HardFail", details: /message has been bounced because/i)
      end

      it "removes the queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the route's mode is Reject" do
      let(:route) { create(:route, server: server, mode: "Reject") }

      it "logs" do
        processor.process
        expect(logger).to have_logged(/route says to bounce/i)
      end

      it "sends a bounce" do
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
        expect(delivery).to have_attributes(status: "HardFail", details: /message has been bounced because/i)
      end

      it "removes the queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the route's endpoint is an HTTP endpoint" do
      let(:endpoint) { create(:http_endpoint, server: server) }
      let(:route) { create(:route, server: server, mode: "Endpoint", endpoint: endpoint) }

      it "gets a sender from the state and sends the message to it" do
        http_sender_double = double("HTTPSender")
        expect(http_sender_double).to receive(:send_message).with(queued_message.message).and_return(SendResult.new)
        expect(state).to receive(:sender_for).with(HTTPSender, endpoint).and_return(http_sender_double)
        processor.process
      end
    end

    context "when the route's endpoint is an SMTP endpoint" do
      let(:endpoint) { create(:smtp_endpoint, server: server) }
      let(:route) { create(:route, server: server, mode: "Endpoint", endpoint: endpoint) }

      it "gets a sender from the state and sends the message to it" do
        smtp_sender_double = double("SMTPSender")
        expect(smtp_sender_double).to receive(:send_message).with(queued_message.message).and_return(SendResult.new)
        expect(state).to receive(:sender_for).with(SMTPSender, message.recipient_domain, nil, { servers: [kind_of(SMTPClient::Server)] }).and_return(smtp_sender_double)
        processor.process
      end
    end

    context "when the route's endpoint is an Address endpoint" do
      let(:endpoint) { create(:address_endpoint, server: server) }
      let(:route) { create(:route, server: server, mode: "Endpoint", endpoint: endpoint) }

      it "gets a sender from the state and sends the message to it" do
        smtp_sender_double = double("SMTPSender")
        expect(smtp_sender_double).to receive(:send_message).with(queued_message.message).and_return(SendResult.new)
        expect(state).to receive(:sender_for).with(SMTPSender, endpoint.domain, nil, { rcpt_to: endpoint.address }).and_return(smtp_sender_double)
        processor.process
      end
    end

    context "when the route's endpoint is an unknown endpoint" do
      let(:route) { create(:route, server: server, mode: "Endpoint", endpoint: create(:webhook, server: server)) }

      it "logs" do
        processor.process
        expect(logger).to have_logged(/invalid endpoint for route/i)
      end

      it "sets the message status to HardFail" do
        processor.process
        expect(message.reload.status).to eq "HardFail"
      end

      it "creates a HardFail delivery" do
        processor.process
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "HardFail", details: /invalid endpoint for route/i)
      end

      it "removes the queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the message has been sent to a sender" do
      let(:endpoint) { create(:smtp_endpoint, server: server) }
      let(:route) { create(:route, server: server, mode: "Endpoint", endpoint: endpoint) }

      let(:send_result) do
        SendResult.new do |result|
          result.type = "Sent"
          result.details = "Sent successfully"
        end
      end

      before do
        smtp_sender_mock = double("SMTPSender")
        allow(SMTPSender).to receive(:new).and_return(smtp_sender_mock)
        allow(smtp_sender_mock).to receive(:start)
        allow(smtp_sender_mock).to receive(:finish)
        allow(smtp_sender_mock).to receive(:send_message).and_return(send_result)
      end

      context "when the sender returns a HardFail and bounces are suppressed" do
        before do
          send_result.type = "HardFail"
          send_result.suppress_bounce = true
        end

        it "logs" do
          processor.process
          expect(logger).to have_logged(/suppressing bounce message after hard fail/)
        end

        it "does not send a bounce" do
          allow(BounceMessage).to receive(:new)
          processor.process
          expect(BounceMessage).to_not have_received(:new)
        end
      end

      context "when the sender returns a HardFail and bounces should be sent" do
        before do
          send_result.type = "HardFail"
          send_result.details = "Failed to send message"
        end

        it "logs" do
          processor.process
          expect(logger).to have_logged(/sending a bounce because message hard failed/)
        end

        it "sends a bounce" do
          expect(BounceMessage).to receive(:new).with(server, queued_message.message)
          processor.process
        end

        it "sets the message status to HardFail" do
          processor.process
          expect(message.reload.status).to eq "HardFail"
        end

        it "creates a delivery with the details and a suffix about the bounce message" do
          processor.process
          delivery = message.deliveries.last
          expect(delivery).to have_attributes(status: "HardFail", details: /Failed to send message. Sent bounce message to sender \(see message <msg:\d+>\)/i)
        end
      end

      it "creates a delivery with the result from the sender" do
        send_result.output = "some output here"
        send_result.secure = true
        send_result.log_id = "12345"
        send_result.time = 2.32

        processor.process
        delivery = message.deliveries.last
        expect(delivery).to have_attributes(status: "Sent",
                                            details: "Sent successfully",
                                            output: "some output here",
                                            sent_with_ssl: true,
                                            log_id: "12345",
                                            time: 2.32)
      end

      context "when the sender wants to retry" do
        before do
          send_result.type = "SoftFail"
          send_result.retry = true
        end

        it "logs" do
          processor.process
          expect(logger).to have_logged(/message requeued for trying later, at/i)
        end

        it "sets the message status to SoftFail" do
          processor.process
          expect(message.reload.status).to eq "SoftFail"
        end

        it "updates the queued message with a new retry time" do
          Timecop.freeze do
            retry_time = 5.minutes.from_now.change(usec: 0)
            processor.process
            expect(queued_message.reload.retry_after).to eq retry_time
          end
        end

        it "allocates a new IP address to send the message from and updates the queued message" do
          expect(queued_message).to receive(:allocate_ip_address)
          processor.process
        end

        it "does not remove the queued message" do
          processor.process
          expect(queued_message.reload).to be_present
        end
      end

      context "when the sender does not want a retry" do
        it "logs" do
          processor.process
          expect(logger).to have_logged(/message processing completed/i)
        end

        it "sets the message status to Sent" do
          processor.process
          expect(message.reload.status).to eq "Sent"
        end

        it "marks the endpoint as used" do
          route.endpoint.update!(last_used_at: nil)
          Timecop.freeze do
            expect { processor.process }.to change { route.endpoint.reload.last_used_at.to_i }.from(0).to(Time.now.to_i)
          end
        end

        it "removes the queued message" do
          processor.process
          expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context "when an exception occurrs during processing" do
      let(:endpoint) { create(:smtp_endpoint, server: server) }
      let(:route) { create(:route, server: server, mode: "Endpoint", endpoint: endpoint) }

      before do
        smtp_sender_mock = double("SMTPSender")
        allow(SMTPSender).to receive(:new).and_return(smtp_sender_mock)
        allow(smtp_sender_mock).to receive(:start)
        allow(smtp_sender_mock).to receive(:finish)
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
