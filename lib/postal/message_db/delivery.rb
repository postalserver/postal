module Postal
  module MessageDB
    class Delivery

      def self.create(message, attributes = {})
        attributes = message.database.stringify_keys(attributes)
        attributes = attributes.merge('message_id' => message.id, 'timestamp' => Time.now.to_f)
        id = message.database.insert('deliveries', attributes)
        delivery = Delivery.new(message, attributes.merge('id' => id))
        delivery.update_statistics
        delivery.send_webhooks
        delivery
      end

      def initialize(message, attributes)
        @message = message
        @attributes = attributes.stringify_keys
      end

      def method_missing(name, value = nil, &block)
        if @attributes.has_key?(name.to_s)
          @attributes[name.to_s]
        else
          nil
        end
      end

      def timestamp
        @timestamp ||= @attributes['timestamp'] ? Time.zone.at(@attributes['timestamp']) : nil
      end

      def update_statistics
        if self.status == 'Held'
          @message.database.statistics.increment_all(self.timestamp, 'held')
        end

        if self.status == 'Bounced' || self.status == 'HardFail'
          @message.database.statistics.increment_all(self.timestamp, 'bounces')
        end
      end

      def send_webhooks
        if self.webhook_event
          WebhookRequest.trigger(@message.database.server_id, self.webhook_event, self.webhook_hash)
        end
      end

      def webhook_hash
        {
          :message => @message.webhook_hash,
          :status => self.status,
          :details => self.details,
          :output => self.output.to_s.force_encoding('UTF-8').scrub,
          :sent_with_ssl => self.sent_with_ssl,
          :timestamp => @attributes['timestamp'],
          :time => self.time
        }
      end

      def webhook_event
        @webhook_event ||= case self.status
        when 'Sent' then 'MessageSent'
        when 'SoftFail' then 'MessageDelayed'
        when 'HardFail' then 'MessageDeliveryFailed'
        when 'Held' then 'MessageHeld'
        end
      end

    end
  end
end
