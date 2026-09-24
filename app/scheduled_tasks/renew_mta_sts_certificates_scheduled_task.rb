# frozen_string_literal: true

class RenewMTAStsCertificatesScheduledTask < ApplicationScheduledTask

  def call
    Domain.where.not(mta_sts_mode: "none").find_each do |domain|
      next unless domain.mta_sts_certificate_required?

      logger.info "requesting an MTA-STS certificate for #{domain.name}"
      domain.issue_mta_sts_certificate!
    end
  rescue StandardError => e
    logger.error "#{e.class} (#{e.message})"
  end

  def self.next_run_after
    three_am
  end

end
