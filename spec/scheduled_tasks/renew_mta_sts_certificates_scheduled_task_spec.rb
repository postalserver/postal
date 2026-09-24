# frozen_string_literal: true

require "rails_helper"

RSpec.describe RenewMTAStsCertificatesScheduledTask do
  let(:logger) { TestLogger.new }

  subject(:task) { described_class.new(logger: logger) }

  describe "#call" do
    it "requests a certificate for a domain which needs one" do
      create(:domain, mta_sts_mode: "testing")
      expect_any_instance_of(Domain).to receive(:issue_mta_sts_certificate!)
      task.call
      expect(logger).to have_logged(/requesting an MTA-STS certificate/)
    end

    it "does not request a certificate for a domain which has no policy" do
      create(:domain, mta_sts_mode: "none")
      expect_any_instance_of(Domain).to_not receive(:issue_mta_sts_certificate!)
      task.call
    end

    it "does not request a certificate while the current one is still valid" do
      create(:domain, mta_sts_mode: "testing", mta_sts_certificate_expires_at: 60.days.from_now)
      expect_any_instance_of(Domain).to_not receive(:issue_mta_sts_certificate!)
      task.call
    end

    it "records an error rather than failing the task when a certificate cannot be requested" do
      domain = create(:domain, mta_sts_mode: "testing")
      allow_any_instance_of(Domain).to receive(:issue_mta_sts_certificate!)
        .and_raise(Postal::ACME::Error, "the order was rejected")
      expect { task.call }.to_not raise_error
      expect(logger).to have_logged(/the order was rejected/)
      expect(domain.mta_sts_certificate_status).to be_nil
    end
  end

  describe ".next_run_after" do
    it "runs in the early hours" do
      expect(described_class.next_run_after.hour).to eq 3
    end
  end
end
