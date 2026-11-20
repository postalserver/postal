# frozen_string_literal: true

require "net/http"

module Postal
  module MessageInspectors
    class Rspamd < MessageInspector

      class Error < StandardError
      end

      def inspect_message(inspection)
        response = request(inspection.message, inspection.scope)
        response = JSON.parse(response.body)
        return unless response["symbols"].is_a?(Hash)

        response["symbols"].each_value do |symbol|
          next if symbol["description"].blank?

          inspection.spam_checks << SpamCheck.new(symbol["name"], symbol["score"], symbol["description"])
        end

        add_authentication_results(inspection, response)
      rescue Error => e
        inspection.spam_checks << SpamCheck.new("ERROR", 0, e.message)
      end

      private

      # When rspamd's milter_headers module runs the authentication-results
      # routine, the response asks for an Authentication-Results header with
      # rspamd's SPF, DKIM and DMARC verdicts. Keep it for incoming mail so
      # the message can carry it on to its route. rspamd sends the header as a
      # string, as {"value" => ...}, or as an array of those.
      def add_authentication_results(inspection, response)
        return unless inspection.scope == :incoming

        add_headers = response.dig("milter", "add_headers")
        return unless add_headers.is_a?(Hash)

        value = Array.wrap(add_headers["Authentication-Results"]).first
        value = value["value"] if value.is_a?(Hash)
        return unless value.is_a?(String) && value.present?

        # A line break is fine only as folding, followed by a space or tab.
        value = value.gsub(/\r?\n(?=[ \t])/, "\r\n")
        return if value =~ /\r\n(?![ \t])|(?<!\r)\n|\r(?!\n)/

        inspection.headers << "Authentication-Results: #{value}"
      end

      def request(message, scope)
        http = Net::HTTP.new(@config.host, @config.port)
        http.use_ssl = true if @config.ssl
        http.read_timeout = 10
        http.open_timeout = 10

        raw_message = message.raw_message

        request = Net::HTTP::Post.new("/checkv2")
        request.body = raw_message
        request["Content-Length"] = raw_message.bytesize.to_s
        request["Password"] = @config.password if @config.password
        request["Flags"] = @config.flags if @config.flags
        request["User-Agent"] = "Postal"
        request["Deliver-To"] = message.rcpt_to
        request["From"] = message.mail_from
        request["Rcpt"] = message.rcpt_to
        request["Queue-Id"] = message.token

        if scope == :outgoing
          request["User"] = ""
          # We don't actually know the IP but an empty input here will
          # still trigger rspamd to treat this as an outbound email
          # and disable certain checks.
          # https://rspamd.com/doc/tutorials/scanning_outbound.html
          request["Ip"] = ""
        elsif (sender = message.received_from)
          # Without the sending server's address rspamd can't check SPF, and
          # its other IP-based checks have nothing to go on. ReceivedHeader.parse
          # returns no HELO when the client sent something other than a plain
          # hostname or address literal.
          request["Ip"] = sender[:ip_address]
          request["Helo"] = sender[:helo] if sender[:helo]
        end

        response = nil
        begin
          response = http.request(request)
        rescue StandardError => e
          logger.error "Error talking to rspamd: #{e.class} (#{e.message})"
          logger.error e.backtrace[0, 5]

          raise Error, "Error when scanning with rspamd (#{e.class})"
        end

        unless response.is_a?(Net::HTTPOK)
          logger.info "Got #{response.code} status from rspamd, wanted 200"
          raise Error, "Error when scanning with rspamd (got #{response.code})"
        end

        response
      end

    end
  end
end
