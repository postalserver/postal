# frozen_string_literal: true

# This class can be used to generate a message which can be used for the purposes of
# testing within the given server.
class MessageFactory

  def initialize(server)
    @server = server
  end

  def incoming(route: nil, &block)
    @message = @server.message_db.new_message
    @message.scope = "incoming"
    @message.rcpt_to = "test@example.com"
    @message.mail_from = "john@example.com"

    if route
      @message.rcpt_to = route.description
      @message.route_id = route.id
    end

    create_message(&block)
  end

  def outgoing(domain: nil, credential: nil, &block)
    @message = @server.message_db.new_message
    @message.scope = "outgoing"
    @message.rcpt_to = "john@example.com"
    @message.mail_from = "test@example.com"

    if domain
      @message.mail_from = "test@#{domain.name}"
      @message.domain_id = domain.id
    end

    if credential
      @message.credential_id = credential.id
    end

    create_message(&block)
  end

  class << self

    def incoming(server, **kwargs, &block)
      new(server).incoming(**kwargs, &block)
    end

    def outgoing(server, **kwargs, &block)
      new(server).outgoing(**kwargs, &block)
    end

  end

  private

  def create_message
    mail = create_mail(@message.rcpt_to, @message.mail_from)

    if block_given?
      yield @message, mail
    end

    @message.raw_message = mail.to_s
    @message.save(queue_on_create: false)
    @message
  end

  def create_mail(to, from)
    mail = Mail.new
    mail.to = to
    mail.from = from
    mail.subject = "An example message"
    mail.body = "Hello world!"
    mail
  end

end
