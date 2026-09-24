# frozen_string_literal: true

require "rails_helper"

RSpec.describe PruneTLSReportsScheduledTask do
  let(:logger) { TestLogger.new }
  let(:domain) { create(:domain) }

  subject(:task) { described_class.new(logger: logger) }

  def create_report(report_id, created_at: Time.current)
    TLSReport.create!(domain: domain, report_id: report_id, created_at: created_at)
  end

  def retention
    described_class::RETENTION
  end

  describe "#call" do
    it "removes reports which are older than the retention period" do
      old = create_report("old", created_at: (retention + 1.day).ago)

      expect { task.call }.to change(TLSReport, :count).by(-1)
      expect(TLSReport.exists?(old.id)).to be false
      expect(logger).to have_logged(/older than/)
    end

    it "keeps reports which are within the retention period" do
      create_report("recent", created_at: 1.day.ago)

      expect { task.call }.to_not change(TLSReport, :count)
    end

    it "removes a report which is right on the boundary" do
      create_report("boundary", created_at: (retention + 1.hour).ago)

      expect { task.call }.to change(TLSReport, :count).by(-1)
    end

    it "removes the failures along with their report" do
      old = create_report("old", created_at: (retention + 1.day).ago)
      old.results.create!(result_type: "certificate-expired", failed_session_count: 1)

      expect { task.call }.to change(TLSReportResult, :count).by(-1)
    end
  end

  describe ".next_run_after" do
    it "runs in the early hours" do
      expect(described_class.next_run_after.hour).to eq 3
    end
  end
end
