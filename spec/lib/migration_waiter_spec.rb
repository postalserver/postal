# frozen_string_literal: true

require "rails_helper"

RSpec.describe MigrationWaiter do
  describe ".wait" do
    it "returns without waiting when there are no pending migrations" do
      expect(described_class).not_to receive(:sleep)
      expect(Process).not_to receive(:exit)
      described_class.wait
    end

    it "exits after all attempts have been used while migrations are still pending" do
      stub_const("MigrationWaiter::ATTEMPTS", 2)
      allow_any_instance_of(ActiveRecord::Migrator).to receive(:pending_migrations).and_return([double])
      expect(described_class).to receive(:sleep).once
      expect(Process).to receive(:exit).with(1).and_raise(SystemExit)
      expect { described_class.wait }.to raise_error(SystemExit)
    end
  end
end
