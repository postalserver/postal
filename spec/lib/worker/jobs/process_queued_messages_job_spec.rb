# frozen_string_literal: true

require "rails_helper"

module Worker
  module Jobs

    RSpec.describe ProcessQueuedMessagesJob do
      subject(:job) { described_class.new(logger: Postal.logger) }

      before do
        allow(MessageDequeuer).to receive(:process)
      end

      describe "#call" do
        context "when there are no queued messages" do
          it "does nothing" do
            job.call
            expect(MessageDequeuer).to_not have_received(:process)
          end
        end

        context "when there is an unlocked queued message for an IP address that is not ours" do
          it "does nothing" do
            ip_address = create(:ip_address)
            queued_message = create(:queued_message, ip_address: ip_address)
            job.call
            expect(MessageDequeuer).to_not have_received(:process)
            expect(queued_message.reload.locked?).to be false
          end
        end

        context "when there is an unlocked queued message without an IP address without a retry time" do
          it "locks the message and calls the service" do
            queued_message = create(:queued_message, ip_address: nil, retry_after: nil)
            job.call
            expect(MessageDequeuer).to have_received(:process).with(queued_message, logger: kind_of(Klogger::Logger))
            expect(queued_message.reload.locked?).to be true
            expect(queued_message.locked_by).to match(/\A#{Postal.locker_name} [a-f0-9]{16}\z/)
            expect(queued_message.locked_at).to be_within(1.second).of(Time.current)
          end
        end

        context "when there is an unlocked queued message without an IP address without a retry time in the past" do
          it "locks the message and calls the service" do
            queued_message = create(:queued_message, ip_address: nil, retry_after: 10.minutes.ago)
            job.call
            expect(MessageDequeuer).to have_received(:process).with(queued_message, logger: kind_of(Klogger::Logger))
            expect(queued_message.reload.locked?).to be true
            expect(queued_message.locked_by).to match(/\A#{Postal.locker_name} [a-f0-9]{16}\z/)
            expect(queued_message.locked_at).to be_within(1.second).of(Time.current)
          end
        end

        context "when there is an unlocked queued message without an IP address without a retry time in the future" do
          it "does nothing" do
            queued_message = create(:queued_message, ip_address: nil, retry_after: 10.minutes.from_now)
            job.call
            expect(MessageDequeuer).to_not have_received(:process)
            expect(queued_message.reload.locked?).to be false
          end
        end

        context "when there is a locked queued message without an IP address without a retry time" do
          it "does nothing" do
            queued_message = create(:queued_message, :locked, ip_address: nil, retry_after: nil)
            job.call
            expect(MessageDequeuer).to_not have_received(:process)
            expect(queued_message.reload.locked?).to be true
          end
        end

        context "when there is a locked queued message without an IP address with a retry time in the past" do
          it "does nothing" do
            queued_message = create(:queued_message, :locked, ip_address: nil, retry_after: 1.month.ago)
            job.call
            expect(MessageDequeuer).to_not have_received(:process)
            expect(queued_message.reload.locked?).to be true
          end
        end

        context "when there is an unlocked queued message with an IP address that is ours without a retry time" do
          it "locks the message and calls the service" do
            ip_address = create(:ip_address, ipv4: "10.20.30.40")
            allow(Socket).to receive(:ip_address_list).and_return([Addrinfo.new(["AF_INET", 1, "localhost.localdomain", "10.20.30.40"])])
            queued_message = create(:queued_message, ip_address: ip_address)
            job.call
            expect(MessageDequeuer).to have_received(:process).with(queued_message, logger: kind_of(Klogger::Logger))
            expect(queued_message.reload.locked?).to be true
            expect(queued_message.locked_by).to match(/\A#{Postal.locker_name} [a-f0-9]{16}\z/)
            expect(queued_message.locked_at).to be_within(1.second).of(Time.current)
          end
        end

        context "when there is an unlocked queued message with an IP address that is ours without a retry time in the future" do
          it "does nothing" do
            ip_address = create(:ip_address, ipv4: "10.20.30.40")
            allow(Socket).to receive(:ip_address_list).and_return([Addrinfo.new(["AF_INET", 1, "localhost.localdomain", "10.20.30.40"])])
            queued_message = create(:queued_message, ip_address: ip_address, retry_after: 1.month.from_now)
            job.call
            expect(MessageDequeuer).to_not have_received(:process)
            expect(queued_message.reload.locked?).to be false
          end
        end
      end
    end

  end
end
