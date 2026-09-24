# frozen_string_literal: true

# One failure from an aggregate TLS report. A report carries a policy and the
# failures which were seen against it, so each row repeats the policy it belongs
# to and carries the reason the sessions failed. Grouping on `result_type` is
# what tells an operator which failure is worth acting on.
class TLSReportResult < ApplicationRecord

  belongs_to :tls_report

end
