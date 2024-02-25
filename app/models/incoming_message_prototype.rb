# frozen_string_literal: true

class IncomingMessagePrototype

  attr_accessor :to
  attr_accessor :from
  attr_accessor :route_id
  attr_accessor :subject
  attr_accessor :plain_body
  attr_accessor :attachments

  def initialize(server, ip, source_type, attributes)
    @server = server
    @ip = ip
    @source_type = source_type
    @attachments = []
    attributes.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
  end

  def from_address
    @from.gsub(/.*</, "").gsub(/>.*/, "").strip
  end

  def route
    @route ||= if @to.present?
                 uname, domain = @to.split("@", 2)
                 uname, _tag = uname.split("+", 2)
                 @server.routes.includes(:domain).where(domains: { name: domain }, name: uname).first
               end
  end

  # rubocop:disable Lint/DuplicateMethods
  def attachments
    (@attachments || []).map do |attachment|
      {
        name: attachment[:name],
        content_type: attachment[:content_type] || "application/octet-stream",
        data: attachment[:base64] ? Base64.decode64(attachment[:data]) : attachment[:data]
      }
    end
  end
  # rubocop:enable Lint/DuplicateMethods

  def create_messages
    if valid?
      messages = route.create_messages do |message|
        message.rcpt_to = @to
        message.mail_from = from_address
        message.raw_message = raw_message
      end
      { route.description => { id: messages.first.id, token: messages.first.token } }
    else
      false
    end
  end

  def valid?
    validate
    errors.empty?
  end

  def errors
    @errors || []
  end

  def validate
    @errors = []
    if route.nil?
      @errors << "NoRoutesFound"
    end

    if from.empty?
      @errors << "FromAddressMissing"
    end

    if subject.blank?
      @errors << "SubjectMissing"
    end
    @errors
  end

  def raw_message
    @raw_message ||= begin
      mail = Mail.new
      mail.to = @to
      mail.from = @from
      mail.subject = @subject
      mail.text_part = @plain_body
      mail.message_id = "<#{SecureRandom.uuid}@#{Postal::Config.dns.return_path_domain}>"
      attachments.each do |attachment|
        mail.attachments[attachment[:name]] = {
          mime_type: attachment[:content_type],
          content: attachment[:data]
        }
      end
      mail.header["Received"] = ReceivedHeader.generate(@server, @source_type, @ip, :http)
      mail.to_s
    end
  end

end
