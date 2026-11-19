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

        context "when there are unlocked queued messages with different priorities" do
          it "locks and processes the highest priority message, even if it was queued later" do
            low_priority_message = create(:queued_message, ip_address: nil, server: create(:server, priority: 0))
            high_priority_message = create(:queued_message, ip_address: nil, server: create(:server, priority: 10))
            job.call
            expect(MessageDequeuer).to have_received(:process).once
            expect(MessageDequeuer).to have_received(:process).with(high_priority_message, logger: kind_of(Klogger::Logger))
            expect(high_priority_message.reload.locked?).to be true
            expect(low_priority_message.reload.locked?).to be false
          end
        end

        context "when there are unlocked queued messages with the same priority" do
          it "locks and processes the oldest message first" do
            server = create(:server, priority: 5)
            first_message = create(:queued_message, ip_address: nil, server: server)
            second_message = create(:queued_message, ip_address: nil, server: server)
            job.call
            expect(MessageDequeuer).to have_received(:process).once
            expect(MessageDequeuer).to have_received(:process).with(first_message, logger: kind_of(Klogger::Logger))
            expect(first_message.reload.locked?).to be true
            expect(second_message.reload.locked?).to be false
          end
        end

        context "when the worker has a minimum priority" do
          before do
            allow(Postal::Config.worker).to receive(:minimum_priority).and_return(5)
          end

          it "does not lock or process messages below the minimum priority" do
            queued_message = create(:queued_message, ip_address: nil, server: create(:server, priority: 4))
            job.call
            expect(MessageDequeuer).to_not have_received(:process)
            expect(queued_message.reload.locked?).to be false
          end

          it "locks and processes messages at the minimum priority" do
            queued_message = create(:queued_message, ip_address: nil, server: create(:server, priority: 5))
            job.call
            expect(MessageDequeuer).to have_received(:process).with(queued_message, logger: kind_of(Klogger::Logger))
            expect(queued_message.reload.locked?).to be true
          end
        end
      end
    end

  end
end
