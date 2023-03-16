structure :message do
  basic :id
  basic :token

  expansion(:status) do
    {
      status: o.status,
      last_delivery_attempt: o.last_delivery_attempt ? o.last_delivery_attempt.to_f : nil,
      held: o.held == 1,
      hold_expiry: o.hold_expiry ? o.hold_expiry.to_f : nil
    }
  end

  expansion(:details) do
    {
      rcpt_to: o.rcpt_to,
      mail_from: o.mail_from,
      subject: o.subject,
      message_id: o.message_id,
      timestamp: o.timestamp.to_f,
      direction: o.scope,
      size: o.size,
      bounce: o.bounce,
      bounce_for_id: o.bounce_for_id,
      tag: o.tag,
      received_with_ssl: o.received_with_ssl
    }
  end

  expansion(:inspection) do
    {
      inspected: o.inspected == 1,
      spam: o.spam == 1,
      spam_score: o.spam_score.to_f,
      threat: o.threat == 1,
      threat_details: o.threat_details
    }
  end

  expansion(:plain_body) { o.plain_body }

  expansion(:html_body) { o.html_body }

  expansion(:attachments) do
    o.attachments.map do |attachment|
      {
        filename: attachment.filename.to_s,
        content_type: attachment.mime_type,
        data: Base64.encode64(attachment.body.to_s),
        size: attachment.body.to_s.bytesize,
        hash: Digest::SHA1.hexdigest(attachment.body.to_s)
      }
    end
  end

  expansion(:headers) { o.headers }

  expansion(:raw_message) { Base64.encode64(o.raw_message) }

  expansion(:activity_entries) do
    {
      loads: o.loads,
      clicks: o.clicks
    }
  end
end
