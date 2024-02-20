# frozen_string_literal: true

module GeneralHelpers

  def create_plain_text_message(server, text, to = "test@example.com", override_attributes = {})
    domain = create(:domain, owner: server)
    attributes = { from: "test@#{domain.name}", subject: "Test Plain Text Message" }.merge(override_attributes)
    attributes[:to] = to
    attributes[:plain_body] = text
    message = OutgoingMessagePrototype.new(server, "127.0.0.1", "testsuite", attributes)
    result = message.create_message(to)
    server.message_db.message(result[:id])
  end

end
