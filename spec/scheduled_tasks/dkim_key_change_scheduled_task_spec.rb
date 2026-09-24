# frozen_string_literal: true

require "rails_helper"

RSpec.describe DKIMKeyChangeScheduledTask do
  let(:logger) { TestLogger.new }
  let(:organization) { create(:organization) }

  subject(:task) { described_class.new(logger: logger) }

  describe "#call" do
    it "reminds the owner about a key change which has been waiting to be published" do
      domain = create(:domain, owner: organization, dkim_status: "OK")
      domain.regenerate_dkim_key!
      domain.update_column(:pending_dkim_key_created_at, 8.days.ago)

      task.call

      expect(domain.reload.pending_dkim_key_notified_at).to be_a Time
      expect(logger).to have_logged(/reminding about the pending DKIM key/)
    end

    it "does not remind the owner about a recent key change" do
      domain = create(:domain, owner: organization, dkim_status: "OK")
      domain.regenerate_dkim_key!

      task.call

      expect(domain.reload.pending_dkim_key_notified_at).to be_nil
    end

    it "reminds the owner only once for a key change" do
      domain = create(:domain, owner: organization, dkim_status: "OK")
      domain.regenerate_dkim_key!
      domain.update_column(:pending_dkim_key_created_at, 8.days.ago)

      task.call
      first_reminder = domain.reload.pending_dkim_key_notified_at

      task.call

      expect(domain.reload.pending_dkim_key_notified_at).to eq first_reminder
    end
  end

  describe ".next_run_after" do
    it "runs in the early hours" do
      expect(described_class.next_run_after.hour).to eq 3
    end
  end
end
