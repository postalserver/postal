# frozen_string_literal: true

begin
  def add_exception_to_payload(payload, event)
    return unless exception = event.payload[:exception_object]

    payload[:exception_class] = exception.class.name
    payload[:exception_message] = exception.message
    payload[:exception_backtrace] = exception.backtrace[0, 4].join("\n")
  end

  ActiveSupport::Notifications.subscribe "process_action.action_controller" do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)

    payload = {
      event: "request",
      transaction: event.transaction_id,
      controller: event.payload[:controller],
      action: event.payload[:action],
      format: event.payload[:format],
      method: event.payload[:method],
      path: event.payload[:path],
      request_id: event.payload[:request].request_id,
      ip_address: event.payload[:request].ip,
      status: event.payload[:status],
      view_runtime: event.payload[:view_runtime],
      db_runtime: event.payload[:db_runtime]
    }

    add_exception_to_payload(payload, event)

    string = "#{payload[:method]} #{payload[:path]} (#{payload[:status]})"

    if payload[:exception_class]
      Postal.logger.error(string, **payload)
    else
      Postal.logger.info(string, **payload)
    end
  end

  ActiveSupport::Notifications.subscribe "deliver.action_mailer" do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)

    Postal.logger.info({
      event: "send_email",
      transaction: event.transaction_id,
      message_id: event.payload[:message_id],
      subject: event.payload[:subject],
      from: event.payload[:from],
      to: event.payload[:to].is_a?(Array) ? event.payload[:to].join(", ") : event.payload[:to].to_s
    })
  end
end
