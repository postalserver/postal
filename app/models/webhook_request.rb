# frozen_string_literal: true

# == Schema Information
#
# Table name: webhook_requests
#
#  id          :integer          not null, primary key
#  attempts    :integer          default(0)
#  error       :text(65535)
#  event       :string(255)
#  locked_at   :datetime
#  locked_by   :string(255)
#  payload     :text(65535)
#  retry_after :datetime
#  url         :string(255)
#  uuid        :string(255)
#  created_at  :datetime
#  server_id   :integer
#  webhook_id  :integer
#
# Indexes
#
#  index_webhook_requests_on_locked_by  (locked_by)
#

class WebhookRequest < ApplicationRecord

  include HasUUID
  include HasLocking

  belongs_to :server
  belongs_to :webhook, optional: true

  validates :url, presence: true
  validates :event, presence: true

  serialize :payload, type: Hash

  class << self

    def trigger(server, event, payload = {})
      unless server.is_a?(Server)
        server = Server.find(server.to_i)
      end

      webhooks = server.webhooks.enabled.includes(:webhook_events).references(:webhook_events).where("webhooks.all_events = ? OR webhook_events.event = ?", true, event)
      webhooks.each do |webhook|
        server.webhook_requests.create!(event: event, payload: payload, webhook: webhook, url: webhook.url)
      end
    end

  end

end
