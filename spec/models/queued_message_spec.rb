# frozen_string_literal: true

# == Schema Information
#
# Table name: queued_messages
#
#  id            :integer          not null, primary key
#  attempts      :integer          default(0)
#  batch_key     :string(255)
#  domain        :string(255)
#  locked_at     :datetime
#  locked_by     :string(255)
#  manual        :boolean          default(FALSE)
#  retry_after   :datetime
#  created_at    :datetime
#  updated_at    :datetime
#  ip_address_id :integer
#  message_id    :integer
#  route_id      :integer
#  server_id     :integer
#
# Indexes
#
#  index_queued_messages_on_domain      (domain)
#  index_queued_messages_on_message_id  (message_id)
#  index_queued_messages_on_server_id   (server_id)
#
require "rails_helper"

RSpec.describe QueuedMessage do
  subject(:queued_message) { build(:queued_message) }

  describe "relationships" do
    it { is_expected.to belong_to(:server) }
    it { is_expected.to belong_to(:ip_address).optional }
  end

  describe ".ready_with_delayed_retry" do
    it "returns messages where retry after is null" do
      message = create(:queued_message, retry_after: nil)
      expect(described_class.ready_with_delayed_retry).to eq [message]
    end

    it "returns messages where retry after is less than 30 seconds from now" do
      Timecop.freeze do
        message1 = create(:queued_message, retry_after: 45.seconds.ago)
        message2 = create(:queued_message, retry_after: 5.minutes.ago)
        create(:queued_message, retry_after: Time.now)
        create(:queued_message, retry_after: 1.minute.from_now)
        expect(described_class.ready_with_delayed_retry.order(:id)).to eq [message1, message2]
      end
    end
  end

  describe ".with_stale_lock" do
    it "returns messages where lock time is less than the configured number of stale days" do
      allow(Postal::Config.postal).to receive(:queued_message_lock_stale_days).and_return(2)
      message1 = create(:queued_message, locked_at: 3.days.ago, locked_by: "test")
      message2 = create(:queued_message, locked_at: 2.days.ago, locked_by: "test")
      create(:queued_message, locked_at: 1.days.ago, locked_by: "test")
      create(:queued_message)
      expect(described_class.with_stale_lock.order(:id)).to eq [message1, message2]
    end
  end

  describe "#retry_now" do
    it "removes the retry time" do
      message = create(:queued_message, retry_after: 2.minutes.from_now)
      expect { message.retry_now }.to change { message.reload.retry_after }.from(kind_of(Time)).to(nil)
    end

    it "raises an error if invalid" do
      message = create(:queued_message, retry_after: 2.minutes.from_now)
      message.update_columns(server_id: nil) # unlikely to actually happen
      expect { message.retry_now }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "#send_bounce" do
    let(:server) { create(:server) }
    let(:message) { MessageFactory.incoming(server) }

    subject(:queued_message) { create(:queued_message, message: message) }

    context "when the message is eligiable for bounces" do
      it "queues a bounce message for sending" do
        expect(BounceMessage).to receive(:new).with(server, kind_of(Postal::MessageDB::Message)).and_wrap_original do |original, *args|
          bounce = original.call(*args)
          expect(bounce).to receive(:queue)
          bounce
        end
        queued_message.send_bounce
      end
    end

    context "when the message is not eligible for bounces" do
      it "returns nil" do
        message.update(bounce: true)
        expect(queued_message.send_bounce).to be nil
      end

      it "does not queue a bounce message for sending" do
        message.update(bounce: true)
        expect(BounceMessage).not_to receive(:new)
        queued_message.send_bounce
      end
    end
  end

  describe "#allocate_ip_address" do
    subject(:queued_message) { create(:queued_message) }

    context "when ip pools is disabled" do
      it "returns nil" do
        expect(queued_message.allocate_ip_address).to be nil
      end

      it "does not allocate an IP address" do
        expect { queued_message.allocate_ip_address }.not_to change(queued_message, :ip_address)
      end
    end

    context "when IP pools is enabled" do
      before do
        allow(Postal::Config.postal).to receive(:use_ip_pools?).and_return(true)
      end

      context "when there is no backend message" do
        it "returns nil" do
          expect(queued_message.allocate_ip_address).to be nil
        end

        it "does not allocate an IP address" do
          expect { queued_message.allocate_ip_address }.not_to change(queued_message, :ip_address)
        end
      end

      context "when no IP pool can be determined for the message" do
        let(:server) { create(:server) }
        let(:message) { MessageFactory.outgoing(server) }

        subject(:queued_message) { create(:queued_message, message: message) }

        it "returns nil" do
          expect(queued_message.allocate_ip_address).to be nil
        end

        it "does not allocate an IP address" do
          expect { queued_message.allocate_ip_address }.not_to change(queued_message, :ip_address)
        end
      end

      context "when an IP pool can be determined for the message" do
        let(:ip_pool) { create(:ip_pool, :with_ip_address) }
        let(:server) { create(:server, ip_pool: ip_pool) }
        let(:message) { MessageFactory.outgoing(server) }

        subject(:queued_message) { create(:queued_message, message: message) }

        it "returns an IP address" do
          expect(queued_message.allocate_ip_address).to be_a IPAddress
        end

        it "allocates an IP address to the queued message" do
          queued_message.update(ip_address: nil)
          expect { queued_message.allocate_ip_address }.to change(queued_message, :ip_address).from(nil).to(ip_pool.ip_addresses.first)
        end
      end
    end
  end

  describe "#batchable_messages" do
    context "when the message is not locked" do
      subject(:queued_message) { build(:queued_message) }

      it "raises an error" do
        expect { queued_message.batchable_messages }.to raise_error(Postal::Error, /must lock current message before locking any friends/i)
      end
    end

    context "when the message is locked" do
      let(:batch_key) { nil }
      subject(:queued_message) { build(:queued_message, :locked, batch_key: batch_key) }

      context "when there is no batch key on the queued message" do
        it "returns an empty array" do
          expect(queued_message.batch_key).to be nil
          expect(queued_message.batchable_messages).to eq []
        end
      end

      context "when there is a batch key" do
        let(:batch_key) { "1234" }

        it "finds and locks messages with the same batch key and IP address up to the limit specified" do
          other_message1 = create(:queued_message, batch_key: batch_key, ip_address: nil)
          other_message2 = create(:queued_message, batch_key: batch_key, ip_address: nil)
          create(:queued_message, batch_key: batch_key, ip_address: nil)

          messages = queued_message.batchable_messages(2)
          expect(messages).to eq [other_message1, other_message2]
          expect(messages).to all be_locked
        end

        it "does not find messages with a different batch key" do
          create(:queued_message, batch_key: "5678", ip_address: nil)
          expect(queued_message.batchable_messages).to eq []
        end

        it "does not find messages that are not queued for sending yet" do
          create(:queued_message, batch_key: batch_key, ip_address: nil, retry_after: 1.minute.from_now)
          expect(queued_message.batchable_messages).to eq []
        end

        it "does not find messages that are for a different IP address" do
          create(:queued_message, batch_key: batch_key, ip_address: create(:ip_address))
          expect(queued_message.batchable_messages).to eq []
        end
      end
    end
  end
end
