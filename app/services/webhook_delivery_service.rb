# frozen_string_literal: true

class WebhookDeliveryService

  def initialize(webhook_delivery:)
    @webhook_delivery = webhook_delivery
  end

  # TODO: move the logic from WebhookDelivery#deliver in to this service.
  #
  def call
    if @webhook_delivery.deliver
      log "Succesfully delivered"
    else
      log "Delivery failed"
    end
  end

end
