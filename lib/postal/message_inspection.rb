require 'timeout'
require 'socket'
require 'json'

module Postal
  class MessageInspection

    SPAM_EXCLUSIONS = {
      :outgoing => ['NO_RECEIVED', 'NO_RELAYS', 'ALL_TRUSTED', 'FREEMAIL_FORGED_REPLYTO', 'RDNS_DYNAMIC', 'CK_HELO_GENERIC', /^SPF\_/, /^HELO\_/, /DKIM_/, /^RCVD_IN_/],
      :incoming => []
    }

    def initialize(message, scope = :incoming)
      @message = message
      @scope = scope
      @threat = false
      @spam_score = 0.0
      @spam_checks = []

      if Postal.config.spamd.enabled?
        scan_for_spam
      end

      if Postal.config.clamav.enabled?
        scan_for_threats
      end
    end

    def spam_score
      @spam_score
    end

    def spam_checks
      @spam_checks
    end

    def filtered_spam_checks
      @filtered_spam_checks ||= @spam_checks.reject do |check|
        SPAM_EXCLUSIONS[@scope].any? do |item|
          item == check.code || (item.is_a?(Regexp) && item =~ check.code)
        end
      end
    end

    def filtered_spam_score
      filtered_spam_checks.inject(0.0) do |total, check|
        total += check.score || 0.0
      end.round(2)
    end

    def threat?
      @threat
    end

    def threat_message
      @threat_message
    end

    private

    def scan_for_spam
      data = nil
      Timeout.timeout(15) do
        tcp_socket = TCPSocket.new(Postal.config.spamd.host, Postal.config.spamd.port)
        tcp_socket.write("REPORT SPAMC/1.2\r\n")
        tcp_socket.write("Content-length: #{@message.bytesize}\r\n")
        tcp_socket.write("\r\n")
        tcp_socket.write(@message)
        tcp_socket.close_write
        data = tcp_socket.read
      end

      spam_checks = []
      total = 0.0
      rules = data ? data.split(/^---(.*)\r?\n/).last.split(/\r?\n/) : []
      while line = rules.shift
        if line =~ /\A([\- ]?[\d\.]+)\s+(\w+)\s+(.*)/
          total += $1.to_f
          spam_checks << SPAMCheck.new($2, $1.to_f, $3)
        else
          spam_checks.last.description << " " + line.strip
        end
      end

      @spam_score = total.round(1)
      @spam_checks = spam_checks

    rescue Timeout::Error
      @spam_checks = [SPAMCheck.new("TIMEOUT", 0, "Timed out when scanning for spam")]
    rescue => e
      logger.error "Error talking to spamd: #{e.class} (#{e.message})"
      logger.error e.backtrace[0,5]
      @spam_checks = [SPAMCheck.new("ERROR", 0, "Error when scanning for spam")]
    ensure
      tcp_socket.close rescue nil
    end

    def scan_for_threats
      @threat = false

      data = nil
      Timeout.timeout(10) do
        tcp_socket = TCPSocket.new(Postal.config.clamav.host, Postal.config.clamav.port)
        tcp_socket.write("zINSTREAM\0")
        tcp_socket.write([@message.bytesize].pack("N"))
        tcp_socket.write(@message)
        tcp_socket.write([0].pack("N"))
        tcp_socket.close_write
        data = tcp_socket.read
      end

      if data && data =~ /\Astream\:\s+(.*?)[\s\0]+?/
        if $1.upcase == 'OK'
          @threat = false
          @threat_message = "No threats found"
        else
          @threat = true
          @threat_message = $1
        end
      else
        @threat = false
        @threat_message = "Could not scan message"
      end
    rescue Timeout::Error
      @threat = false
      @threat_message = "Timed out scanning for threats"
    rescue => e
      logger.error "Error talking to clamav: #{e.class} (#{e.message})"
      logger.error e.backtrace[0,5]
      @threat = false
      @threat_message = "Error when scanning for threats"
    ensure
      tcp_socket.close rescue nil
    end

    def logger
      Postal.logger_for(:message_inspection)
    end

  end
end
