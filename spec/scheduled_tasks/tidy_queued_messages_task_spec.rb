# frozen_string_literal: true

require "rails_helper"

RSpec.describe TidyQueuedMessagesTask do
  let(:logger) { TestLogger.new }

  subject(:task) { described_class.new(logger: logger) }

  describe "#call" do
    it "destroys queued messages with stale locks" do
      stale_message = create(:queued_message, locked_at: 2.days.ago, locked_by: "test")
      task.call
      expect { stale_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(logger).to have_logged(/removing queued message \d+/)
    end

    it "does not destroy messages which are not locked" do
      message = create(:queued_message)
      task.call
      expect { message.reload }.not_to raise_error
    end

    it "does not destroy messages which where were locked less then the number of stale days" do
      message = create(:queued_message, locked_at: 10.minutes.ago, locked_by: "test")
      task.call
      expect { message.reload }.not_to raise_error
    end
  end
end
