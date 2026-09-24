# frozen_string_literal: true

require "rails_helper"

RSpec.describe TLSReport do
  let(:domain) { create(:domain, name: "example.com") }

  let(:payload) do
    {
      "organization-name" => "Example Organization",
      "date-range" => {
        "start-datetime" => "2026-09-18T00:00:00Z",
        "end-datetime" => "2026-09-19T00:00:00Z"
      },
      "contact-info" => "mailto:tlsrpt@example.net",
      "report-id" => "example-20260918-001",
      "policies" => [
        {
          "policy" => { "policy-type" => "sts", "policy-domain" => "example.com", "mx-host" => "mx1.example.com" },
          "summary" => { "total-successful-session-count" => 1200, "total-failure-session-count" => 3 },
          "failure-details" => [
            {
              "result-type" => "certificate-expired",
              "sending-mta-ip" => "203.0.113.10",
              "receiving-mx-hostname" => "mx1.example.com",
              "failed-session-count" => 3,
              "failure-reason-code" => "expired"
            },
          ]
        },
      ]
    }
  end

  # Build the message a sending server would deliver to the report address.
  def report_message(content, compress: true, headers: {})
    content = JSON.generate(content) unless content.is_a?(String)

    if compress
      buffer = StringIO.new
      writer = Zlib::GzipWriter.new(buffer)
      writer.write(content)
      writer.close
      content = buffer.string
      type = "application/tlsrpt+gzip"
    else
      type = "application/tlsrpt+json"
    end

    lines = [
      "From: reporter@example.net",
      "To: tlsrpt@example.com",
      "Subject: TLS report",
      "MIME-Version: 1.0",
    ]
    headers.each { |name, value| lines << "#{name}: #{value}" }
    lines += [
      "Content-Type: multipart/report; report-type=tlsrpt; boundary=BOUNDARY",
      "",
      "--BOUNDARY",
      "Content-Type: text/plain",
      "",
      "This is an TLS report.",
      "--BOUNDARY",
      "Content-Type: #{type}",
      "Content-Transfer-Encoding: base64",
      "",
      Base64.strict_encode64(content),
      "--BOUNDARY--",
      "",
    ]
    lines.join("\r\n")
  end

  describe ".ingest" do
    it "stores a compressed report" do
      report = described_class.ingest(domain, report_message(payload))
      expect(report).to be_a described_class
      expect(report.report_id).to eq "example-20260918-001"
      expect(report.organization_name).to eq "Example Organization"
      expect(report.successful_session_count).to eq 1200
      expect(report.failed_session_count).to eq 3
      expect(report.date_start).to eq Time.zone.parse("2026-09-18T00:00:00Z")
    end

    it "stores an uncompressed report" do
      report = described_class.ingest(domain, report_message(payload, compress: false))
      expect(report.report_id).to eq "example-20260918-001"
    end

    it "records the MTA which submitted the report" do
      report = described_class.ingest(domain, report_message(payload, headers: { "TLS-Report-Submitter" => "sender.example.net" }))
      expect(report.submitter).to eq "sender.example.net"
    end

    it "stores a report which names the domain it was delivered for" do
      report = described_class.ingest(domain, report_message(payload, headers: { "TLS-Report-Domain" => "example.com" }))
      expect(report).to be_a described_class
    end

    it "ignores a report which names a different domain" do
      message = report_message(payload, headers: { "TLS-Report-Domain" => "another.example" })
      expect(described_class.ingest(domain, message)).to be_nil
      expect(described_class.count).to eq 0
    end

    it "ignores a report which has already been received" do
      described_class.ingest(domain, report_message(payload))
      expect(described_class.ingest(domain, report_message(payload))).to be_nil
      expect(described_class.count).to eq 1
    end

    it "accepts the same report id for a different domain" do
      other = create(:domain)
      described_class.ingest(domain, report_message(payload))
      expect(described_class.ingest(other, report_message(payload))).to be_a described_class
    end

    it "ignores a message which does not contain a report" do
      message = "From: reporter@example.net\r\nTo: tlsrpt@example.com\r\n\r\nNothing here.\r\n"
      expect(described_class.ingest(domain, message)).to be_nil
    end

    it "ignores a report which is not valid JSON" do
      expect(described_class.ingest(domain, report_message("this is not json"))).to be_nil
    end

    it "ignores a report which is not an object" do
      expect(described_class.ingest(domain, report_message("[1, 2, 3]"))).to be_nil
    end

    it "ignores a report which does not identify itself" do
      expect(described_class.ingest(domain, report_message(payload.except("report-id")))).to be_nil
    end

    it "rejects a report which expands beyond the size which will be accepted" do
      large = { "report-id" => "large", "padding" => "x" * 6.megabytes }
      expect(described_class.ingest(domain, report_message(large))).to be_nil
    end
  end

  describe "the stored failures" do
    it "stores each failure the report describes" do
      report = described_class.ingest(domain, report_message(payload))

      expect(report.results.count).to eq 1
      result = report.results.first
      expect(result.result_type).to eq "certificate-expired"
      expect(result.sending_mta_ip).to eq "203.0.113.10"
      expect(result.receiving_mx_hostname).to eq "mx1.example.com"
      expect(result.failed_session_count).to eq 3
      expect(result.failure_reason_code).to eq "expired"
    end

    it "records the policy each failure was seen against" do
      report = described_class.ingest(domain, report_message(payload))

      result = report.results.first
      expect(result.policy_type).to eq "sts"
      expect(result.policy_domain).to eq "example.com"
      expect(result.mx_host).to eq "mx1.example.com"
    end

    it "stores failures from every policy in the report" do
      policies = payload["policies"] + [
        {
          "policy" => { "policy-type" => "sts", "policy-domain" => "example.com", "mx-host" => "mx2.example.com" },
          "summary" => { "total-successful-session-count" => 10, "total-failure-session-count" => 2 },
          "failure-details" => [
            { "result-type" => "starttls-not-supported", "failed-session-count" => 2 },
          ]
        },
      ]

      report = described_class.ingest(domain, report_message(payload.merge("policies" => policies)))

      expect(report.results.pluck(:result_type)).to match_array %w[certificate-expired starttls-not-supported]
      expect(report.failed_session_count).to eq 5
    end

    it "stores no failures when the report describes none" do
      quiet = payload.merge("policies" => [{ "policy" => { "policy-domain" => "example.com" }, "summary" => {} }])
      report = described_class.ingest(domain, report_message(quiet))

      expect(report.results).to be_empty
    end

    it "discards the failures with the report" do
      report = described_class.ingest(domain, report_message(payload))

      expect { report.destroy }.to change(TLSReportResult, :count).by(-1)
    end
  end

  def create_report(report_id, dom = domain, created_at: Time.current)
    described_class.create!(domain: dom, report_id: report_id, created_at: created_at)
  end

  def create_failures(report_id, failures)
    report = create_report(report_id)
    failures.each { |type, count| report.results.create!(result_type: type, failed_session_count: count) }
    report
  end

  describe ".recent_for" do
    it "returns the reports for the domain, most recent first" do
      older = create_report("older", created_at: 2.days.ago)
      newer = create_report("newer")

      expect(described_class.recent_for(domain).to_a).to eq [newer, older]
    end

    it "does not return reports which belong to another domain" do
      other = create(:domain)
      create_report("other", other)
      mine = create_report("mine")

      expect(described_class.recent_for(domain).to_a).to eq [mine]
    end

    it "returns no more reports than it is asked for" do
      3.times { |i| create_report("report-#{i}") }

      expect(described_class.recent_for(domain, limit: 2).size).to eq 2
    end
  end

  describe ".failure_totals_for" do
    it "adds up the failed sessions by the reason which was given" do
      create_failures("one", { "certificate-expired" => 3 })
      create_failures("two", { "certificate-expired" => 2, "starttls-not-supported" => 3 })

      expect(described_class.failure_totals_for(domain)).to eq(
        "certificate-expired" => 5,
        "starttls-not-supported" => 3
      )
    end

    it "does not count failures which belong to another domain" do
      other = create(:domain)
      report = create_report("other", other)
      report.results.create!(result_type: "certificate-expired", failed_session_count: 9)

      expect(described_class.failure_totals_for(domain)).to eq({})
    end
  end

  it "discards a report whose domain was removed before the message arrived" do
    domain.destroy

    expect(described_class.ingest(domain, report_message(payload))).to be_nil
    expect(described_class.count).to eq 0
  end
end
