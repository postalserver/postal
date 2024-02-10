# frozen_string_literal: true

class SendWebhookJob < Postal::Job

  def perform
    if server = Server.find(params["server_id"])
      new_items = {}
      params["payload"]&.each do |key, value|
        next unless key.to_s =~ /\A_(\w+)/

        begin
          new_items[::Regexp.last_match(1)] = server.message_db.message(value.to_i).webhook_hash
        rescue Postal::MessageDB::Message::NotFound
        end
      end

      new_items.each do |key, value|
        params["payload"].delete("_#{key}")
        params["payload"][key] = value
      end

      WebhookRequest.trigger(server, params["event"], params["payload"])
    else
      log "Couldn't find server with ID #{params['server_id']}"
    end
  end

end
