# frozen_string_literal: true

# An aggregate TLS report which a sending server has submitted for a domain. The
# sender assigns the report id and repeats it if the report is delivered again,
# so it is what identifies a report which has already been received.
class TLSReport < ApplicationRecord

  belongs_to :domain
  has_many :results, class_name: "TLSReportResult", dependent: :destroy

  # The most policies and failure details a single report may contribute.
  # Reports arrive unauthenticated from third parties, so without a bound one
  # message could create an unbounded number of rows in a single transaction.
  MAX_POLICIES = 100
  MAX_FAILURE_DETAILS = 100

  # Ingest a report which has been delivered for a domain.
  #
  # @param domain [Domain] the domain the report was submitted for
  # @param raw [String] the message as it was received
  # @return [TLSReport, nil] nil when the message carried no usable report, when
  #   the report was about a different domain, or when it has already been
  #   received
  def self.ingest(domain, raw)
    parser = Postal::TLSRpt::Parser.new(raw)
    payload = parser.parse

    # A report which names a domain other than the address it was delivered to
    # has been sent to the wrong place, so it is not attributed to whichever
    # domain happened to receive it.
    return nil if parser.report_domain.present? && !parser.report_domain.casecmp?(domain.name)

    report_id = payload["report-id"].to_s
    # The domain was resolved when the recipient was accepted, and the report only
    # arrives with the message, so it may have been removed in between. A report
    # attributed to a domain which no longer exists would never be seen again.
    return nil unless Domain.exists?(domain.id)

    return nil if report_id.blank?

    policies = payload["policies"].is_a?(Array) ? payload["policies"].first(MAX_POLICIES) : []

    transaction do
      create!(
        domain: domain,
        report_id: report_id.to_s.first(255),
        organization_name: payload["organization-name"].to_s.first(255),
        contact_info: payload["contact-info"].to_s.first(255),
        submitter: parser.submitter.to_s.first(255),
        date_start: parse_time(payload.dig("date-range", "start-datetime")),
        date_end: parse_time(payload.dig("date-range", "end-datetime")),
        successful_session_count: policies.sum { |policy| policy.dig("summary", "total-successful-session-count").to_i },
        failed_session_count: policies.sum { |policy| policy.dig("summary", "total-failure-session-count").to_i },
        payload: JSON.generate(payload),
        results: results_from(policies)
      )
    end
  rescue ActiveRecord::RecordNotUnique, Postal::TLSRpt::Parser::Error
    nil
  end

  # The reports which have been received for a domain, most recent first. The
  # number returned is bounded because a domain can be reported on by every
  # sending server which talks to it.
  #
  # @param domain [Domain]
  # @param limit [Integer] the most reports to return
  # @return [ActiveRecord::Relation]
  def self.recent_for(domain, limit: 50)
    where(domain_id: domain.id).order(created_at: :desc).limit(limit)
  end

  # The sessions which failed for each reason which has been reported for a
  # domain, which is what tells an operator which failure to act on.
  #
  # @param domain [Domain]
  # @return [Hash{String => Integer}] the failed sessions keyed by reason
  def self.failure_totals_for(domain)
    TLSReportResult.joins(:tls_report)
                   .where(tls_reports: { domain_id: domain.id })
                   .group(:result_type)
                   .sum(:failed_session_count)
  end

  # The failures in a report, each carrying the policy it was seen against.
  #
  # @param policies [Array<Hash>] the policies from the report
  # @return [Array<TLSReportResult>]
  def self.results_from(policies)
    policies.flat_map do |policy|
      details = policy["failure-details"].is_a?(Array) ? policy["failure-details"].first(MAX_FAILURE_DETAILS) : []

      details.map do |detail|
        TLSReportResult.new(
          policy_type: policy.dig("policy", "policy-type").to_s.first(255),
          policy_domain: policy.dig("policy", "policy-domain").to_s.first(255),
          mx_host: policy.dig("policy", "mx-host").to_s.first(255),
          result_type: detail["result-type"].to_s.first(255),
          sending_mta_ip: detail["sending-mta-ip"].to_s.first(255),
          receiving_mx_hostname: detail["receiving-mx-hostname"].to_s.first(255),
          failed_session_count: detail["failed-session-count"].to_i,
          failure_reason_code: detail["failure-reason-code"].to_s.first(255)
        )
      end
    end
  end
  private_class_method :results_from

  def self.parse_time(value)
    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
  private_class_method :parse_time

end
