# frozen_string_literal: true

require "rails_helper"

module MessageDequeuer

  RSpec.describe Base do
    describe ".new" do
      context "when given state" do
        it "uses that state" do
          base = described_class.new(nil, logger: nil, state: 1234)
          expect(base.state).to eq 1234
        end
      end

      context "when not given state" do
        it "creates a new state" do
          base = described_class.new(nil, logger: nil)
          expect(base.state).to be_a State
        end
      end
    end

    describe ".process" do
      it "creates a new instances of the class and calls process" do
        message = create(:queued_message)
        logger = TestLogger.new

        mock = double("Base")
        expect(mock).to receive(:process).once
        expect(described_class).to receive(:new).with(message, logger: logger).and_return(mock)

        described_class.process(message, logger: logger)
      end
    end
  end

end
