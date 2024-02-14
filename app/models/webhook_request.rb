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

  RETRIES = { 1 => 2.minutes, 2 => 3.minutes, 3 => 6.minutes, 4 => 10.minutes, 5 => 15.minutes }.freeze

  belongs_to :server
  belongs_to :webhook, optional: true

  validates :url, presence: true
  validates :event, presence: true

  serialize :payload, Hash

  def deliver
    payload = { event: event, timestamp: created_at.to_f, payload: self.payload, uuid: uuid }.to_json
    Postal.logger.tagged(event: event, url: url) do
      Postal.logger.info "Sending webhook request"
      result = Postal::HTTP.post(url, sign: true, json: payload, timeout: 5)
      self.attempts += 1
      self.retry_after = RETRIES[self.attempts]&.from_now
      server.message_db.webhooks.record(
        event: event,
        url: url,
        webhook_id: webhook_id,
        attempt: self.attempts,
        timestamp: Time.now.to_f,
        payload: self.payload.to_json,
        uuid: uuid,
        status_code: result[:code],
        body: result[:body],
        will_retry: (retry_after ? 0 : 1)
      )

      if result[:code] >= 200 && result[:code] < 300
        Postal.logger.info "Received #{result[:code]} status code. That's OK."
        destroy!
        webhook&.update_column(:last_used_at, Time.now)
        true
      else
        Postal.logger.error "Received #{result[:code]} status code. That's not OK."
        self.error = "Couldn't send to URL. Code received was #{result[:code]}"
        if retry_after
          Postal.logger.info "Will retry #{retry_after} (this was attempt #{self.attempts})"
          self.locked_by = nil
          self.locked_at = nil
          save!
        else
          Postal.logger.info "Have tried #{self.attempts} times. Giving up."
          destroy!
        end
        false
      end
    end
  end

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
