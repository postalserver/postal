# frozen_string_literal: true

class PruneTLSReportsScheduledTask < ApplicationScheduledTask

  # How long reports are kept. A report is only useful while it informs the
  # MTA-STS enforce decision, and there is one per sending server per day, so a
  # year is enough to see a trend without keeping everything that has ever been
  # received.
  RETENTION = 1.year

  def call
    reports = TLSReport.where("created_at < ?", RETENTION.ago)
    logger.info "pruning TLS reports which are older than #{RETENTION.inspect} (#{reports.count} found)"

    reports.find_each do |report|
      logger.info "removing TLS report #{report.id} for domain #{report.domain_id}"
      report.destroy
    end
  end

  def self.next_run_after
    three_am
  end

end
