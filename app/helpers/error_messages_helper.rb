# frozen_string_literal: true

module ErrorMessagesHelper

  # Renders a record's validation errors.
  #
  # This replaces the helper of the same name from the dynamic_form gem, which
  # is unmaintained and cannot be installed on Ruby 3.4. The markup matches what
  # that gem produced, minus the heading and description which the
  # errorExplanation styles have always hidden, and matches the structure
  # remote.js builds when it renders errors from a remote form.
  def error_messages_for(record)
    record = record.to_model if record.respond_to?(:to_model)
    return "".html_safe if record.nil? || record.errors.empty?

    items = safe_join(record.errors.full_messages.map { |message| tag.li(message) })
    tag.div(tag.ul(items), id: "errorExplanation", class: "errorExplanation")
  end

end
