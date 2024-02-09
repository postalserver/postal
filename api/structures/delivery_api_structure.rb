# frozen_string_literal: true
structure :delivery do
  basic :id
  basic :status
  basic :details
  basic :output, value: proc { o.output&.strip }
  basic :sent_with_ssl, value: proc { o.sent_with_ssl }
  basic :log_id
  basic :time, value: proc { o.time&.to_f }
  basic :timestamp, value: proc { o.timestamp.to_f }
end
