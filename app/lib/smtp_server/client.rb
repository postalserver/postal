# frozen_string_literal: true

module SMTPServer
  class Client

    extend HasPrometheusMetrics
    include HasPrometheusMetrics

    CRAM_MD5_DIGEST = OpenSSL::Digest.new("md5")
    LOG_REDACTION_STRING = "[redacted]"

    attr_reader :logging_enabled
    attr_reader :credential
    attr_reader :ip_address
    attr_reader :recipients
    attr_reader :headers
    attr_reader :state
    attr_reader :helo_name

    def initialize(ip_address)
      @logging_enabled = true
      @ip_address = ip_address

      @cr_present = false
      @previous_cr_present = nil

      if @ip_address
        check_ip_address
        @state = :welcome
      else
        @state = :preauth
      end
      transaction_reset
    end

    def check_ip_address
      return unless @ip_address &&
                    Postal::Config.smtp_server.log_ip_address_exclusion_matcher &&
                    @ip_address =~ Regexp.new(Postal::Config.smtp_server.log_ip_address_exclusion_matcher)

      @logging_enabled = false
    end

    def transaction_reset
      @recipients = []
      @mail_from = nil
      @data = nil
      @headers = nil
    end

    def trace_id
      @trace_id ||= SecureRandom.alphanumeric(8).upcase
    end

    def handle(data)
      if data[-1] == "\r"
        @cr_present = true
        data = data.chop # remove last character (\r)
      else
        # This doesn't use `logger` because that will be nil when logging is disabled
        # and we always want to log this.
        Postal.logger&.warn("Detected line with invalid line ending (missing <CR>)", trace_id: trace_id)
        @cr_present = false
      end

      if @state == :preauth
        return proxy(data)
      end

      logger&.debug "\e[32m<= #{sanitize_input_for_log(data.strip)}\e[0m"
      if @proc
        @proc.call(data)
      else
        handle_command(data)
      end
    ensure
      @previous_cr_present = @cr_present
    end

    def finished?
      @finished || false
    end

    def start_tls?
      @start_tls || false
    end

    attr_writer :start_tls

    def handle_command(data)
      case data
      when /^QUIT/i           then quit
      when /^STARTTLS/i       then starttls
      when /^EHLO/i           then ehlo(data)
      when /^HELO/i           then helo(data)
      when /^RSET/i           then rset
      when /^NOOP/i           then noop
      when /^AUTH PLAIN/i     then auth_plain(data)
      when /^AUTH LOGIN/i     then auth_login(data)
      when /^AUTH CRAM-MD5/i  then auth_cram_md5(data)
      when /^MAIL FROM/i      then mail_from(data)
      when /^RCPT TO/i        then rcpt_to(data)
      when /^DATA/i           then data(data)
      else
        increment_error_count("invalid-command")
        "502 Invalid/unsupported command"
      end
    end

    def logger
      return nil unless @logging_enabled

      @logger ||= Postal.logger.create_tagged_logger(trace_id: trace_id)
    end

    private

    def proxy(data)
      # inet-protocol, client-ip, proxy-ip, client-port, proxy-port
      if m = data.match(/\APROXY (.+) (.+) (.+) (.+) (.+)\z/)
        @ip_address = m[2]
        check_ip_address
        @state = :welcome
        logger&.debug "\e[35mClient identified as #{@ip_address}\e[0m"
        increment_command_count("PROXY")
        return "220 #{Postal::Config.postal.smtp_hostname} ESMTP Postal/#{trace_id}"
      end

      @finished = true
      increment_error_count("proxy-error")
      "502 Proxy Error"
    end

    def quit
      @finished = true
      "221 Closing Connection"
    end

    def starttls
      if Postal::Config.smtp_server.tls_enabled?
        @start_tls = true
        @tls = true
        increment_command_count("STARTLS")
        "220 Ready to start TLS"
      else
        increment_error_count("tls-unavailable")
        "502 TLS not available"
      end
    end

    def ehlo(data)
      @helo_name = data.strip.split(" ", 2)[1]
      transaction_reset
      @state = :welcomed
      increment_command_count("EHLO")
      [
        "250-My capabilities are",
        Postal::Config.smtp_server.tls_enabled? && !@tls ? "250-STARTTLS" : nil,
        "250 AUTH CRAM-MD5 PLAIN LOGIN",
      ].compact
    end

    def helo(data)
      @helo_name = data.strip.split(" ", 2)[1]
      transaction_reset
      @state = :welcomed
      increment_command_count("HELO")
      "250 #{Postal::Config.postal.smtp_hostname}"
    end

    def rset
      transaction_reset
      @state = :welcomed
      increment_command_count("RSET")
      "250 OK"
    end

    def noop
      "250 OK"
    end

    def auth_plain(data)
      increment_command_count("AUTH PLAIN")

      handler = proc do |idata|
        @proc = nil
        idata = Base64.decode64(idata)
        parts = idata.split("\0")
        username = parts[-2]
        password = parts[-1]
        unless username && password
          increment_error_count("missing-credentials")
          next "535 Authenticated failed - protocol error"
        end

        authenticate(password)
      end

      data = data.gsub(/AUTH PLAIN ?/i, "")
      if data.strip == ""
        @proc = handler
        @password_expected_next = true
        "334"
      else
        handler.call(data)
      end
    end

    def auth_login(data)
      increment_command_count("AUTH LOGIN")

      password_handler = proc do |idata|
        @proc = nil
        password = Base64.decode64(idata)
        authenticate(password)
      end

      username_handler = proc do
        @proc = password_handler
        @password_expected_next = true
        "334 UGFzc3dvcmQ6" # "Password:"
      end

      data = data.gsub(/AUTH LOGIN ?/i, "")
      if data.strip == ""
        @proc = username_handler
        "334 VXNlcm5hbWU6" # "Username:"
      else
        username_handler.call(nil)
      end
    end

    def authenticate(password)
      if @credential = Credential.where(type: "SMTP", key: password).first
        @credential.use
        "235 Granted for #{@credential.server.organization.permalink}/#{@credential.server.permalink}"
      else
        logger&.warn "Authentication failure for #{@ip_address}"
        increment_error_count("invalid-credentials")
        "535 Invalid credential"
      end
    end

    def auth_cram_md5(data)
      increment_command_count("AUTH CRAM-MD5")

      challenge = Digest::SHA1.hexdigest(Time.now.to_i.to_s + rand(100_000).to_s)
      challenge = "<#{challenge[0, 20]}@#{Postal::Config.postal.smtp_hostname}>"

      handler = proc do |idata|
        @proc = nil
        username, password = Base64.decode64(idata).split(" ", 2).map { |a| a.chomp }
        org_permlink, server_permalink = username.split(/[\/_]/, 2)
        server = ::Server.includes(:organization).where(organizations: { permalink: org_permlink }, permalink: server_permalink).first
        if server.nil?
          logger&.warn "Authentication failure for #{@ip_address} (no server found matching #{username})"
          increment_error_count("invalid-credentials")
          next "535 Denied"
        end

        grant = nil
        server.credentials.where(type: "SMTP").each do |credential|
          correct_response = OpenSSL::HMAC.hexdigest(CRAM_MD5_DIGEST, credential.key, challenge)
          next unless password == correct_response

          @credential = credential
          @credential.use
          logger&.debug "Authenticated with with credential #{credential.id}"
          grant = "235 Granted for #{credential.server.organization.permalink}/#{credential.server.permalink}"
          break
        end

        if grant.nil?
          logger&.warn "Authentication failure for #{@ip_address} (invalid credential)"
          increment_error_count("invalid-credentials")
          next "535 Denied"
        end

        grant
      end

      @proc = handler
      "334 " + Base64.encode64(challenge).gsub(/[\r\n]/, "")
    end

    def mail_from(data)
      unless in_state(:welcomed, :mail_from_received)
        increment_error_count("mail-from-out-of-order")
        return "503 EHLO/HELO first please"
      end

      @state = :mail_from_received
      transaction_reset
      if data =~ /AUTH=/
        # Discard AUTH= parameter and anything that follows.
        # We don't need this parameter as we don't trust any client to set it
        mail_from_line = data.sub(/ *AUTH=.*/, "")
      else
        mail_from_line = data
      end
      @mail_from = mail_from_line.gsub(/MAIL FROM\s*:\s*/i, "").gsub(/.*</, "").gsub(/>.*/, "").strip
      "250 OK"
    end

    def rcpt_to(data)
      unless in_state(:mail_from_received, :rcpt_to_received)
        increment_error_count("rcpt-to-out-of-order")
        return "503 EHLO/HELO and MAIL FROM first please"
      end

      rcpt_to = data.gsub(/RCPT TO\s*:\s*/i, "").gsub(/.*</, "").gsub(/>.*/, "").strip

      if rcpt_to.blank?
        increment_error_count("empty-rcpt-to")
        return "501 RCPT TO should not be empty"
      end

      uname, domain = rcpt_to.split("@", 2)

      if domain.blank?
        increment_error_count("invalid-rcpt-to")
        return "501 Invalid RCPT TO"
      end

      uname, tag = uname.split("+", 2)

      if domain == Postal::Config.dns.return_path_domain || domain =~ /\A#{Regexp.escape(Postal::Config.dns.custom_return_path_prefix)}\./
        # This is a return path
        @state = :rcpt_to_received
        if server = ::Server.where(token: uname).first
          if server.suspended?
            increment_error_count("server-suspended")
            "535 Mail server has been suspended"
          else
            logger&.debug "Added bounce on server #{server.id}"
            @recipients << [:bounce, rcpt_to, server]
            "250 OK"
          end
        else
          increment_error_count("invalid-server-token")
          "550 Invalid server token"
        end

      elsif domain == Postal::Config.dns.route_domain
        # This is an email direct to a route. This isn't actually supported yet.
        @state = :rcpt_to_received
        if route = Route.where(token: uname).first
          if route.server.suspended?
            increment_error_count("server-suspended")
            "535 Mail server has been suspended"
          elsif route.mode == "Reject"
            increment_error_count("route-rejected")
            "550 Route does not accept incoming messages"
          else
            logger&.debug "Added route #{route.id} to recipients (tag: #{tag.inspect})"
            actual_rcpt_to = "#{route.name}#{tag ? "+#{tag}" : ''}@#{route.domain.name}"
            @recipients << [:route, actual_rcpt_to, route.server, { route: route }]
            "250 OK"
          end
        else
          "550 Invalid route token"
        end

      elsif @credential
        # This is outgoing mail for an authenticated user
        @state = :rcpt_to_received
        if @credential.server.suspended?
          increment_error_count("server-suspended")
          "535 Mail server has been suspended"
        else
          logger&.debug "Added external address '#{rcpt_to}'"
          @recipients << [:credential, rcpt_to, @credential.server]
          "250 OK"
        end

      elsif uname && domain && route = Route.find_by_name_and_domain(uname, domain)
        # This is incoming mail for a route
        @state = :rcpt_to_received
        if route.server.suspended?
          increment_error_count("server-suspended")
          "535 Mail server has been suspended"
        elsif route.mode == "Reject"
          increment_error_count("route-rejection")
          "550 Route does not accept incoming messages"
        else
          logger&.debug "Added route #{route.id} to recipients (tag: #{tag.inspect})"
          @recipients << [:route, rcpt_to, route.server, { route: route }]
          "250 OK"
        end

      else
        # User is trying to relay but is not authenticated. Try to authenticate by IP address
        @credential = Credential.where(type: "SMTP-IP").all.sort_by { |c| c.ipaddr&.prefix || 0 }.reverse.find do |credential|
          credential.ipaddr.include?(@ip_address) || (credential.ipaddr.ipv4? && credential.ipaddr.ipv4_mapped.include?(@ip_address))
        end

        if @credential
          # Retry with credential
          @credential.use
          rcpt_to(data)
        else
          increment_error_count("authentication-required")
          logger&.warn "Authentication failure for #{@ip_address}"
          "530 Authentication required"
        end
      end
    end

    def data(_data)
      unless in_state(:rcpt_to_received)
        increment_error_count("data-out-of-order")
        return "503 HELO/EHLO, MAIL FROM and RCPT TO before sending data"
      end

      @data = String.new.force_encoding("BINARY")
      @headers = {}
      @receiving_headers = true

      received_header = ReceivedHeader.generate(@credential&.server, @helo_name, @ip_address, :smtp)
                                      .force_encoding("BINARY")

      @data << "Received: #{received_header}\r\n"
      @headers["received"] = [received_header]

      handler = proc do |idata|
        if idata == "." && @cr_present && @previous_cr_present
          @logging_enabled = true
          @proc = nil
          finished
        else
          idata = idata.to_s.sub(/\A\.\./, ".")

          if @credential&.server&.log_smtp_data?
            # We want to log if enabled
          else
            logger&.debug "Not logging further message data."
            @logging_enabled = false
          end

          if @receiving_headers
            if idata&.length&.zero?
              @receiving_headers = false
            elsif idata.to_s =~ /^\s/
              # This is a continuation of a header
              if @header_key && @headers[@header_key.downcase] && @headers[@header_key.downcase].last
                @headers[@header_key.downcase].last << idata.to_s
              end
            else
              @header_key, value = idata.split(/:\s*/, 2)
              @headers[@header_key.downcase] ||= []
              @headers[@header_key.downcase] << value
            end
          end
          @data << idata
          @data << "\r\n"
          nil
        end
      end

      @proc = handler
      "354 Go ahead"
    end

    def finished
      if @data.bytesize > Postal::Config.smtp_server.max_message_size.megabytes.to_i
        transaction_reset
        @state = :welcomed
        increment_error_count("message-too-large")
        return format("552 Message too large (maximum size %dMB)", Postal::Config.smtp_server.max_message_size)
      end

      if @headers["received"].grep(/by #{Postal::Config.postal.smtp_hostname}/).count > 4
        transaction_reset
        @state = :welcomed
        increment_error_count("loop-detected")
        return "550 Loop detected"
      end

      authenticated_domain = nil
      if @credential
        authenticated_domain = @credential.server.find_authenticated_domain_from_headers(@headers)
        if authenticated_domain.nil?
          transaction_reset
          @state = :welcomed
          increment_error_count("from-name-invalid")
          return "530 From/Sender name is not valid"
        end
      end

      @recipients.each do |recipient|
        type, rcpt_to, server, options = recipient

        case type
        when :credential
          increment_message_count("outgoing")

          # Outgoing messages are just inserted
          message = server.message_db.new_message
          message.rcpt_to = rcpt_to
          message.mail_from = @mail_from
          message.raw_message = @data
          message.received_with_ssl = @tls
          message.scope = "outgoing"
          message.domain_id = authenticated_domain&.id
          message.credential_id = @credential.id
          message.save

        when :bounce
          increment_message_count("bounce")
          if rp_route = server.routes.where(name: "__returnpath__").first
            # If there's a return path route, we can use this to create the message
            rp_route.create_messages do |msg|
              msg.rcpt_to = rcpt_to
              msg.mail_from = @mail_from
              msg.raw_message = @data
              msg.received_with_ssl = @tls
              msg.bounce = 1
            end
          else
            # There's no return path route, we just need to insert the mesage
            # without going through the route.
            message = server.message_db.new_message
            message.rcpt_to = rcpt_to
            message.mail_from = @mail_from
            message.raw_message = @data
            message.received_with_ssl = @tls
            message.scope = "incoming"
            message.bounce = 1
            message.save
          end
        when :route
          increment_message_count("incoming")
          options[:route].create_messages do |msg|
            msg.rcpt_to = rcpt_to
            msg.mail_from = @mail_from
            msg.raw_message = @data
            msg.received_with_ssl = @tls
          end
        end
      end
      transaction_reset
      @state = :welcomed
      "250 OK"
    end

    def in_state(*states)
      states.include?(@state)
    end

    def sanitize_input_for_log(data)
      if @password_expected_next
        @password_expected_next = false
        if data =~ /\A[a-z0-9]{3,}=*\z/i
          return LOG_REDACTION_STRING
        end
      end

      data = data.dup
      data.gsub!(/(.*AUTH \w+) (.*)\z/i) { "#{::Regexp.last_match(1)} #{LOG_REDACTION_STRING}" }
      data
    end

    def increment_error_count(error)
      increment_prometheus_counter :postal_smtp_server_client_errors, labels: { error: error }
    end

    def increment_command_count(command)
      increment_prometheus_counter :postal_smtp_server_commands_total, labels: { command: command }
    end

    def increment_message_count(type)
      increment_prometheus_counter :postal_smtp_server_messages_total, labels: {
        type: type,
        tls: @tls ? "yes" : "no"
      }
    end

    class << self

      def register_prometheus_metrics
        register_prometheus_counter :postal_smtp_server_commands_total,
                                    docstring: "The number of key commands received by the server",
                                    labels: [:command]

        register_prometheus_counter :postal_smtp_server_client_errors,
                                    docstring: "The number of errors sent to a client",
                                    labels: [:error]

        register_prometheus_counter :postal_smtp_server_messages_total,
                                    docstring: "The number of messages accepted by the SMTP server",
                                    labels: [:type, :tls]
      end

    end

  end
end
