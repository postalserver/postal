module Postal
  class Espect

    def self.inspect(message, scope = :incoming)
      if Postal.config.espect&.hosts
        hosts = Postal.config.espect.hosts.dup.shuffle
        hosts.each do |host|
          result = Postal::HTTP.post("#{host}/inspect", :text_body => Base64.encode64(message), :timeout => 20)
          if result[:code] == 200 && json = (JSON.parse(result[:body]) rescue nil)
            return EspectResult.new(json, scope)
          end
        end
        nil
      end
    end

  end

  class EspectResult

    EXCLUSIONS = {
      :outgoing => ['NO_RECEIVED', 'NO_RELAYS', 'ALL_TRUSTED', 'FREEMAIL_FORGED_REPLYTO', 'RDNS_DYNAMIC', /^SPF\_/, /^HELO\_/, /DKIM_/, /^RCVD_IN_/],
      :incoming => []
    }

    def initialize(reply, scope)
      @reply = reply
      @scope = scope
    end

    def spam_score
      @spam_score ||= begin
        spam_details.inject(0.0) do |total, detail|
          total += detail['score'] || 0.0
        end
      end
    end

    def spam_details
      @spam_details ||= (@reply['spam_details'] || []).reject do |d|
        EXCLUSIONS[@scope].any? do |item|
          item == d['code'] || (item.is_a?(Regexp) && item =~ d['code'])
        end
      end
    end

    def threat?
      @reply['threat'] ? true : false
    end

    def threat_message
      @reply['threat_message']
    end
  end
end
