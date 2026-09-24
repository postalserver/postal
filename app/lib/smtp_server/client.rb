# frozen_string_literal: true

module SMTPServer
  class Client

    extend HasMetrics
    include HasMetrics

    CRAM_MD5_DIGEST = OpenSSL::Digest.new("md5")
    LOG_REDACTION_STRING = "[redacted]"

    # The longest command line we will accept, per RFC 5321 section 4.5.3.2
    # (512 octets including CRLF). Message text is deliberately not capped: real
    # mail routinely contains longer lines and RFC 5321 tells receivers to
    # accept them.
    MAX_COMMAND_LINE_LENGTH = 512

    #
    # Every ESMTP extension this server offers. `keyword` is what appears in the
    # EHLO response, `value` is appended to it when the extension carries one
    # (AUTH's mechanism list), and `available` decides whether the extension
    # applies to the current session. Advertisement and enforcement both read
    # this declaration, so the two cannot drift apart.
    #
    EXTENSIONS = [
      {
        keyword: "STARTTLS",
        available: -> (client) { Postal::Config.smtp_server.tls_enabled? && !client.tls? }
      },
      {
        keyword: "SIZE",
        value: -> (_client) { Postal::Config.smtp_server.max_message_size.megabytes.to_i }
      },
      {
        keyword: "8BITMIME"
      },
      {
        keyword: "SMTPUTF8"
      },
      {
        keyword: "PIPELINING"
      },
      {
        keyword: "AUTH",
        value: "CRAM-MD5 PLAIN LOGIN"
      },
    ].freeze

    #
    # Format a completion reply with its RFC 2034 enhanced status code. The
    # basic code stays first, so a client that ignores enhanced codes is
    # unaffected. Intermediate replies (334, 354) carry no enhanced code.
    #
    def self.reply(code, enhanced, text)
      "#{code} #{enhanced} #{text}"
    end

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
      @received_at = Time.now.to_i

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
      @body_type = "7BIT"
      @smtputf8 = false
    end

    def trace_id
      @trace_id ||= SecureRandom.alphanumeric(8).upcase
    end

    def handle(data)
      @received_at = Time.now.to_i

      # A command line longer than the RFC allows is rejected rather than
      # buffered. Continuation lines for AUTH and DATA are produced by @proc and
      # are handled by their own parsers.
      if @proc.nil? && data.bytesize > MAX_COMMAND_LINE_LENGTH
        increment_error_count("line-too-long")
        return reply(500, "5.5.2", "Line too long")
      end

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

    def tls?
      @tls || false
    end

    #
    # Has this session been quiet for longer than the configured idle timeout?
    # A timeout of zero disables the check.
    #
    def expired?(now = Time.now.to_i)
      timeout = Postal::Config.smtp_server.idle_timeout.to_i
      return false unless timeout.positive?

      @received_at + timeout < now
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
        reply(502, "5.5.2", "Invalid/unsupported command")
      end
    end

    def logger
      return nil unless @logging_enabled

      @logger ||= Postal.logger.create_tagged_logger(trace_id: trace_id)
    end

    private

    def reply(code, enhanced, text)
      self.class.reply(code, enhanced, text)
    end

    #
    # The extensions to advertise for this session, rendered as the keywords the
    # EHLO response carries. A value may be a proc when it depends on the
    # session or the configuration.
    #
    def capabilities
      EXTENSIONS.filter_map do |extension|
        next if extension[:available] && !extension[:available].call(self)

        value = extension[:value]
        value = value.call(self) if value.respond_to?(:call)
        [extension[:keyword], value].compact.join(" ")
      end
    end

    #
    # The address and the ESMTP parameters from a MAIL FROM or RCPT TO command.
    # Parameters are the whitespace-separated tokens following the address,
    # either bare ("SMTPUTF8") or valued ("SIZE=100"), returned keyed by their
    # upper-case name.
    #
    def parse_envelope_command(data, command)
      line = data.sub(/\A#{command}\s*:\s*/i, "").strip
      address, parameters = if line.start_with?("<")
                              address, _, rest = line.partition(">")
                              [address.delete_prefix("<"), rest]
                            else
                              address, _, rest = line.partition(/\s/)
                              [address, rest]
                            end

      parsed = {}
      parameters.to_s.split(/\s+/).each do |token|
        next if token.empty?

        key, value = token.split("=", 2)
        parsed[key.upcase] = value.nil? ? true : value
      end
      [address, parsed]
    end

    #
    # The largest message we will accept, in bytes.
    #
    def max_message_size_bytes
      Postal::Config.smtp_server.max_message_size.megabytes.to_i
    end

    #
    # Attempts to authenticate are counted against the client's IP address. Once
    # the allowance is spent the client is refused outright and disconnected, so
    # a brute-force attempt cannot go on guessing while its failures are merely
    # logged.
    #
    def authentication_refusal
      result = Postal::RateLimiter.check("smtp-auth:#{@ip_address}",
                                         limit: Postal::Config.protection.smtp_auth_attempts_limit,
                                         period: Postal::Config.protection.smtp_auth_attempts_period)
      return nil if result.allowed?

      @finished = true
      increment_error_count("authentication-blocked")
      logger&.warn "Refusing further authentication attempts from #{@ip_address}"
      reply(421, "4.7.0", "Too many failed authentication attempts, try again later")
    end

    #
    # A client which authenticates successfully starts again with a full
    # allowance, so a legitimate user who mistypes a password is not locked out
    # once they get it right.
    #
    def clear_authentication_attempts
      Postal::RateLimiter.clear("smtp-auth:#{@ip_address}")
    end

    #
    # Count one message against this credential's send quota, refusing with a
    # temporary failure when it is spent. Quotas default to unlimited. The
    # quota name selects the per-credential allowance: :smtp_send for SMTP
    # credentials, :smtp_ip_send for matched SMTP-IP credentials.
    #
    # @return [Array, nil] the reply triplet when refused, nil when allowed
    #
    def send_quota_refusal(quota_name)
      return nil if @credential.nil?

      result = Postal::RateLimiter.check_quota(quota_name, @credential)
      return nil unless result.exceeded?

      quota_exceeded_metric(quota_name)
      logger&.warn "Refusing message from #{@ip_address}: #{quota_name} quota spent for credential #{@credential.id}"
      increment_error_count("quota-exceeded")
      [421, "4.7.0", "Too many messages for this credential, try again later"]
    end

    #
    # Count one unauthenticated intake delivery against the client address and
    # kind (bounce, route or TLS report), refusing when the allowance is spent.
    #
    # @return [Array, nil] the reply triplet when refused, nil when allowed
    #
    def unauth_intake_refusal(kind)
      result = Postal::RateLimiter.check_quota(:unauth_intake, @ip_address, kind)
      return nil unless result.exceeded?

      quota_exceeded_metric(:unauth_intake)
      logger&.warn "Refusing #{kind} intake from #{@ip_address}: allowance spent"
      [421, "4.7.0", "Too many messages, try again later"]
    end

    def quota_exceeded_metric(quota_name)
      Postal::Telemetry.increment("postal_quota_exceeded_total", type: quota_name.to_s)
      Postal::Metrics.record("postal_quota_exceeded_total", { type: quota_name.to_s }, 1)
    end

    def proxy(data)
      # inet-protocol, client-ip, proxy-ip, client-port, proxy-port
      if m = data.match(/\APROXY (\S+) (\S+) (\S+) (\S+) (\S+)\z/)
        begin
          claimed = IPAddr.new(m[2])
        rescue IPAddr::InvalidAddressError
          claimed = nil
        end
        unless claimed
          @finished = true
          increment_error_count("proxy-error")
          return reply(502, "5.5.2", "Proxy Error")
        end

        @ip_address = m[2]
        check_ip_address
        @state = :welcome
        logger&.debug "\e[35mClient identified as #{@ip_address}\e[0m"
        increment_command_count("PROXY")
        return reply(220, "2.0.0", "#{Postal::Config.postal.smtp_hostname} ESMTP Postal/#{trace_id}")
      end

      @finished = true
      increment_error_count("proxy-error")
      reply(502, "5.5.2", "Proxy Error")
    end

    def quit
      @finished = true
      reply(221, "2.0.0", "Closing Connection")
    end

    def starttls
      unless in_state(:welcomed)
        increment_error_count("starttls-out-of-order")
        return reply(503, "5.5.1", "STARTTLS not available now")
      end

      if Postal::Config.smtp_server.tls_enabled?
        @start_tls = true
        @tls = true
        increment_command_count("STARTTLS")
        # RFC 3207 section 4.2: everything learned before the handshake is
        # discarded, so the client must introduce itself again over the
        # encrypted channel before it can send mail.
        @helo_name = nil
        @credential = nil
        transaction_reset
        @state = :welcome
        reply(220, "2.0.0", "Ready to start TLS")
      else
        increment_error_count("tls-unavailable")
        reply(502, "5.5.1", "TLS not available")
      end
    end

    def ehlo(data)
      @helo_name = data.strip.split(" ", 2)[1]
      transaction_reset
      @state = :welcomed
      increment_command_count("EHLO")
      extensions = capabilities
      lines = ["250-My capabilities are"]
      extensions.each_with_index do |extension, index|
        # Every line but the last is continued, so the client knows the
        # response has ended when it sees a space rather than a hyphen.
        separator = index == extensions.size - 1 ? " " : "-"
        lines << "250#{separator}#{extension}"
      end
      lines
    end

    def helo(data)
      @helo_name = data.strip.split(" ", 2)[1]
      transaction_reset
      @state = :welcomed
      increment_command_count("HELO")
      reply(250, "2.0.0", Postal::Config.postal.smtp_hostname)
    end

    def rset
      transaction_reset
      @state = :welcomed
      increment_command_count("RSET")
      reply(250, "2.0.0", "OK")
    end

    def noop
      reply(250, "2.0.0", "OK")
    end

    def auth_plain(data)
      increment_command_count("AUTH PLAIN")

      unless in_state(:welcomed)
        increment_error_count("auth-out-of-order")
        return reply(503, "5.5.1", "AUTH not available now")
      end

      handler = proc do |idata|
        @proc = nil
        idata = Base64.decode64(idata)
        parts = idata.split("\0")
        username = parts[-2]
        password = parts[-1]
        unless username && password
          increment_error_count("missing-credentials")
          next reply(535, "5.7.8", "Authentication failed - protocol error")
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

      unless in_state(:welcomed)
        increment_error_count("auth-out-of-order")
        return reply(503, "5.5.1", "AUTH not available now")
      end

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
      if (refusal = authentication_refusal)
        return refusal
      end

      if @credential = Credential.where(type: "SMTP", key: password).first
        @credential.use
        clear_authentication_attempts
        reply(235, "2.7.0", "Granted for #{@credential.server.organization.permalink}/#{@credential.server.permalink}")
      else
        logger&.warn "Authentication failure for #{@ip_address}"
        increment_error_count("invalid-credentials")
        reply(535, "5.7.8", "Invalid credential")
      end
    end

    def auth_cram_md5(data)
      increment_command_count("AUTH CRAM-MD5")

      unless in_state(:welcomed)
        increment_error_count("auth-out-of-order")
        return reply(503, "5.5.1", "AUTH not available now")
      end

      challenge = SecureRandom.hex(16)
      challenge = "<#{challenge}@#{Postal::Config.postal.smtp_hostname}>"

      handler = proc do |idata|
        @proc = nil
        if (refusal = authentication_refusal)
          next refusal
        end

        username, password = Base64.decode64(idata).split(" ", 2).map { |a| a.chomp }
        org_permlink, server_permalink = username.split(/[\/_]/, 2)
        server = ::Server.includes(:organization).where(organizations: { permalink: org_permlink }, permalink: server_permalink).first
        if server.nil?
          logger&.warn "Authentication failure for #{@ip_address} (no server found matching #{username})"
          increment_error_count("invalid-credentials")
          next reply(535, "5.7.8", "Denied")
        end

        grant = nil
        server.credentials.where(type: "SMTP").each do |credential|
          correct_response = OpenSSL::HMAC.hexdigest(CRAM_MD5_DIGEST, credential.key, challenge)
          next unless password.bytesize == correct_response.bytesize &&
                      ActiveSupport::SecurityUtils.secure_compare(password, correct_response)

          @credential = credential
          @credential.use
          clear_authentication_attempts
          logger&.debug "Authenticated with with credential #{credential.id}"
          grant = reply(235, "2.7.0", "Granted for #{credential.server.organization.permalink}/#{credential.server.permalink}")
          break
        end

        if grant.nil?
          logger&.warn "Authentication failure for #{@ip_address} (invalid credential)"
          increment_error_count("invalid-credentials")
          next reply(535, "5.7.8", "Denied")
        end

        grant
      end

      @proc = handler
      "334 " + Base64.encode64(challenge).gsub(/[\r\n]/, "")
    end

    def mail_from(data)
      unless in_state(:welcomed, :mail_from_received)
        increment_error_count("mail-from-out-of-order")
        return reply(503, "5.5.1", "EHLO/HELO first please")
      end

      address, parameters = parse_envelope_command(data, "MAIL FROM")

      # We don't trust a client to assert AUTH=, so the parameter is discarded
      # rather than carried into the transaction.
      parameters.delete("AUTH")

      # RFC 6152: the client tells us whether the body is seven or eight bit. We
      # keep the octets either way, so anything we do not recognise is refused
      # rather than silently downgraded.
      body = parameters["BODY"]
      if body && body != true && !%w[7BIT 8BITMIME].include?(body.upcase)
        increment_error_count("invalid-body-value")
        return reply(501, "5.5.4", "Unsupported BODY value")
      end
      body_type = body.nil? || body == true ? "7BIT" : body.upcase

      # A client which declares a size larger than we accept is refused before
      # it sends the message rather than after.
      declared_size = parameters["SIZE"]
      if declared_size && declared_size != true && declared_size.to_i > max_message_size_bytes
        increment_error_count("message-too-large")
        return reply(552, "5.3.4",
                     format("Message too large (maximum size %dMB)",
                            Postal::Config.smtp_server.max_message_size))
      end

      # The transaction is only committed once the parameters have been accepted,
      # so a refused MAIL FROM leaves the session exactly as it was.
      @state = :mail_from_received
      transaction_reset
      @mail_from = address
      @body_type = body_type
      # RFC 6531: the client is telling us the envelope and headers may contain
      # UTF-8. Nothing in the receive path is ASCII-restricted, so accepting the
      # parameter is what makes it true.
      @smtputf8 = parameters.key?("SMTPUTF8")
      reply(250, "2.1.0", "OK")
    end

    def rcpt_to(data)
      unless in_state(:mail_from_received, :rcpt_to_received)
        increment_error_count("rcpt-to-out-of-order")
        return reply(503, "5.5.1", "EHLO/HELO and MAIL FROM first please")
      end

      max_recipients = Postal::Config.smtp_server.max_recipients.to_i
      if max_recipients.positive? && @recipients.size >= max_recipients
        increment_error_count("too-many-recipients")
        return reply(452, "4.5.3", "Too many recipients")
      end

      rcpt_to = data.gsub(/RCPT TO\s*:\s*/i, "").gsub(/.*</, "").gsub(/>.*/, "").strip

      if rcpt_to.blank?
        increment_error_count("empty-rcpt-to")
        return reply(501, "5.1.3", "RCPT TO should not be empty")
      end

      uname, domain = rcpt_to.split("@", 2)

      if domain.blank?
        increment_error_count("invalid-rcpt-to")
        return reply(501, "5.1.3", "Invalid RCPT TO")
      end

      uname, tag = uname.split("+", 2)

      if domain == Postal::Config.dns.return_path_domain || domain =~ /\A#{Regexp.escape(Postal::Config.dns.custom_return_path_prefix)}\./
        # This is a return path
        @state = :rcpt_to_received
        if server = ::Server.where(token: uname).first
          if server.suspended?
            increment_error_count("server-suspended")
            reply(535, "5.7.8", "Mail server has been suspended")
          else
            logger&.debug "Added bounce on server #{server.id}"
            @recipients << [:bounce, rcpt_to, server]
            reply(250, "2.1.5", "OK")
          end
        else
          increment_error_count("invalid-server-token")
          reply(550, "5.1.1", "Invalid server token")
        end

      elsif (tls_rpt_local_part = Postal::Config.dns.tls_rpt_local_part.to_s.downcase).present? &&
            uname.to_s.downcase == tls_rpt_local_part &&
            (report_domain = ::Domain.where(name: domain).first)
        # Reports are consumed by the application rather than delivered, so no
        # route is involved. The domain the report was submitted for is carried
        # as the third element of the recipient.
        @state = :rcpt_to_received
        logger&.debug "Added TLS report for #{report_domain.name}"
        @recipients << [:tls_report, rcpt_to, report_domain]
        reply(250, "2.1.5", "OK")

      elsif domain == Postal::Config.dns.route_domain
        # This is an email direct to a route. This isn't actually supported yet.
        @state = :rcpt_to_received
        if route = Route.where(token: uname).first
          if route.server.suspended?
            increment_error_count("server-suspended")
            reply(535, "5.7.8", "Mail server has been suspended")
          elsif route.mode == "Reject"
            increment_error_count("route-rejected")
            reply(550, "5.7.1", "Route does not accept incoming messages")
          else
            logger&.debug "Added route #{route.id} to recipients (tag: #{tag.inspect})"
            actual_rcpt_to = "#{route.name}#{tag ? "+#{tag}" : ''}@#{route.domain.name}"
            @recipients << [:route, actual_rcpt_to, route.server, { route: route }]
            reply(250, "2.1.5", "OK")
          end
        else
          reply(550, "5.1.1", "Invalid route token")
        end

      elsif @credential
        # This is outgoing mail for an authenticated user
        @state = :rcpt_to_received
        if @credential.server.suspended?
          increment_error_count("server-suspended")
          reply(535, "5.7.8", "Mail server has been suspended")
        else
          logger&.debug "Added external address '#{rcpt_to}'"
          @recipients << [:credential, rcpt_to, @credential.server]
          reply(250, "2.1.5", "OK")
        end

      elsif uname && domain && route = Route.find_by_name_and_domain(uname, domain)
        # This is incoming mail for a route
        @state = :rcpt_to_received
        if route.server.suspended?
          increment_error_count("server-suspended")
          reply(535, "5.7.8", "Mail server has been suspended")
        elsif route.mode == "Reject"
          increment_error_count("route-rejection")
          reply(550, "5.7.1", "Route does not accept incoming messages")
        else
          logger&.debug "Added route #{route.id} to recipients (tag: #{tag.inspect})"
          @recipients << [:route, rcpt_to, route.server, { route: route }]
          reply(250, "2.1.5", "OK")
        end

      else
        # User is trying to relay but is not authenticated. Try to authenticate by IP address
        @credential = Credential.where(type: "SMTP-IP").all.sort_by { |c| c.ipaddr&.prefix || 0 }.reverse.find do |credential|
          next false if credential.ipaddr.nil?

          credential.ipaddr.include?(@ip_address) || (credential.ipaddr.ipv4? && credential.ipaddr.ipv4_mapped.include?(@ip_address))
        end

        if @credential
          # Retry with credential
          @credential.use
          rcpt_to(data)
        else
          increment_error_count("authentication-required")
          logger&.warn "Authentication failure for #{@ip_address}"
          reply(530, "5.7.0", "Authentication required")
        end
      end
    end

    def data(_data)
      unless in_state(:rcpt_to_received)
        increment_error_count("data-out-of-order")
        return reply(503, "5.5.1", "HELO/EHLO, MAIL FROM and RCPT TO before sending data")
      end

      @data = String.new.force_encoding("BINARY")
      @headers = {}
      @receiving_headers = true

      received_header = ReceivedHeader.generate(@credential&.server, @helo_name, @ip_address, :smtp,
                                                smtputf8: @smtputf8)
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
        return reply(552, "5.3.4",
                     format("Message too large (maximum size %dMB)", Postal::Config.smtp_server.max_message_size))
      end

      if @headers["received"].grep(/by #{Postal::Config.postal.smtp_hostname}/).count > 4
        transaction_reset
        @state = :welcomed
        increment_error_count("loop-detected")
        return reply(550, "5.4.6", "Loop detected")
      end

      authenticated_domain = nil
      if @credential
        authenticated_domain = @credential.server.find_authenticated_domain_from_headers(@headers)
        if authenticated_domain.nil?
          transaction_reset
          @state = :welcomed
          increment_error_count("from-name-invalid")
          return reply(530, "5.7.1", "From/Sender name is not valid")
        end

        quota_name = @credential.type == "SMTP-IP" ? :smtp_ip_send : :smtp_send
        if (refusal = send_quota_refusal(quota_name))
          transaction_reset
          @state = :welcomed
          return reply(*refusal)
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
          if (refusal = unauth_intake_refusal("bounce"))
            transaction_reset
            @state = :welcomed
            return reply(*refusal)
          end
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
        when :tls_report
          # The third element of the recipient is the domain for this type.
          increment_message_count("tls_report")
          if (refusal = unauth_intake_refusal("tls_report"))
            transaction_reset
            @state = :welcomed
            return reply(*refusal)
          end
          ::TLSReport.ingest(server, @data)

        when :route
          increment_message_count("incoming")
          if (refusal = unauth_intake_refusal("route"))
            transaction_reset
            @state = :welcomed
            return reply(*refusal)
          end
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
      reply(250, "2.0.0", "OK")
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
      increment_counter :postal_smtp_server_client_errors, labels: { error: error }
    end

    def increment_command_count(command)
      increment_counter :postal_smtp_server_commands_total, labels: { command: command }
    end

    def increment_message_count(type)
      increment_counter :postal_smtp_server_messages_total, labels: {
        type: type,
        tls: @tls ? "yes" : "no"
      }
    end

    class << self

      def register_metrics
        register_counter :postal_smtp_server_commands_total,
                                    docstring: "The number of key commands received by the server",
                                    labels: [:command]

        register_counter :postal_smtp_server_client_errors,
                                    docstring: "The number of errors sent to a client",
                                    labels: [:error]

        register_counter :postal_smtp_server_messages_total,
                                    docstring: "The number of messages accepted by the SMTP server",
                                    labels: [:type, :tls]
      end

    end

  end
end
