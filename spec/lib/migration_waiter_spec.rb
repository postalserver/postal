# frozen_string_literal: true

require "rails_helper"
require "migration_waiter"

RSpec.describe MigrationWaiter do
  describe ".pending_migration_count" do
    # This talks to Active Record's migration APIs directly and is the part of
    # this class most likely to break on a Rails upgrade. The rest of this
    # class is stubbed, so this example is what actually exercises it.
    it "returns the number of migrations which have not been applied" do
      expect(described_class.pending_migration_count).to be_a Integer
    end

    it "returns zero when the test database is up to date" do
      expect(described_class.pending_migration_count).to eq 0
    end
  end

  describe ".wait" do
    before do
      allow(Postal.logger).to receive(:info)
      allow(described_class).to receive(:sleep)
    end

    it "returns immediately when there are no pending migrations" do
      allow(described_class).to receive(:pending_migration_count).and_return(0)
      described_class.wait
      expect(described_class).to have_received(:pending_migration_count).once
      expect(described_class).to_not have_received(:sleep)
    end

    it "waits until there are no pending migrations remaining" do
      allow(described_class).to receive(:pending_migration_count).and_return(2, 1, 0)
      described_class.wait
      expect(described_class).to have_received(:sleep).with(described_class::SLEEP_TIME).twice
    end

    it "exits when migrations are still pending after the maximum number of attempts" do
      stub_const("#{described_class}::ATTEMPTS", 3)
      allow(described_class).to receive(:pending_migration_count).and_return(1)
      # Process.exit raises SystemExit for real. It has to do so here too,
      # otherwise the wait loop never terminates.
      allow(Process).to receive(:exit).and_raise(SystemExit)

      expect { described_class.wait }.to raise_error(SystemExit)

      expect(Process).to have_received(:exit).with(1)
      expect(described_class).to have_received(:sleep).twice
    end
  end

  describe ".wait_if_appropriate" do
    before do
      allow(described_class).to receive(:wait)
      allow(described_class).to receive(:console?).and_return(false)
      allow(described_class).to receive(:rake_task?).and_return(false)
      allow(described_class).to receive(:rails_command?).and_return(false)
    end

    context "when the migration waiter is not enabled" do
      it "does not wait" do
        allow(Postal::Config.migration_waiter).to receive(:enabled?).and_return(false)
        described_class.wait_if_appropriate
        expect(described_class).to_not have_received(:wait)
      end
    end

    context "when the migration waiter is enabled" do
      before do
        allow(Postal::Config.migration_waiter).to receive(:enabled?).and_return(true)
      end

      it "waits" do
        described_class.wait_if_appropriate
        expect(described_class).to have_received(:wait)
      end

      %w[console? rake_task? rails_command?].each do |predicate|
        it "does not wait when #{predicate.delete_suffix('?')} is true" do
          allow(described_class).to receive(predicate).and_return(true)
          described_class.wait_if_appropriate
          expect(described_class).to_not have_received(:wait)
        end
      end
    end
  end
end
