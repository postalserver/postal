# frozen_string_literal: true

require "rails_helper"

RSpec.describe MessageDequeuer do
  describe ".process" do
    it "calls the initial process with the given message and logger" do
      message = create(:queued_message)
      logger = TestLogger.new

      mock = double("InitialProcessor")
      expect(mock).to receive(:process).with(no_args)
      expect(MessageDequeuer::InitialProcessor).to receive(:new).with(message, logger: logger).and_return(mock)

      described_class.process(message, logger: logger)
    end
  end
end
