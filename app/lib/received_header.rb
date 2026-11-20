# frozen_string_literal: true

class ReceivedHeader

  OUR_HOSTNAMES = {
    smtp: Postal::Config.postal.smtp_hostname,
    http: Postal::Config.postal.web_hostname
  }.freeze

  class << self

    def generate(server, helo, ip_address, method)
      our_hostname = OUR_HOSTNAMES[method]
      if our_hostname.nil?
        raise Error, "`method` is invalid (must be one of #{OUR_HOSTNAMES.join(', ')})"
      end

      header = "by #{our_hostname} with #{method.to_s.upcase}; #{Time.now.utc.rfc2822}"

      if server.nil? || server.privacy_mode == false
        hostname = DNSResolver.local.ip_to_hostname(ip_address)
        header = "from #{helo} (#{hostname} [#{ip_address}]) #{header}"
      end

      header
    end

    # A HELO name worth passing on: a hostname, or an address literal such as
    # [192.0.2.1] or [IPv6:2001:db8::1].
    PLAIN_HELO = /\A(?:[A-Za-z0-9_.-]{1,255}|\[(?:IPv6:)?[0-9A-Fa-f:.]{1,45}\])\z/

    # Read the sending server's HELO and IP address back out of a Received
    # header that .generate wrote when the message arrived over SMTP.
    #
    # The client chooses its HELO name, and the SMTP server keeps it as sent,
    # spaces and brackets included. A HELO name can therefore copy this
    # header's own "(host [address]) by ... with SMTP; ..." tail. So the
    # address comes from the end of the header, where .generate put it, and
    # never from anything the client wrote. The date .generate appends holds
    # no semicolon, so the last "with SMTP; " is always ours.
    #
    # @param header [String] the header's value, without the "Received:" name
    # @return [Hash, nil] :ip_address, and :helo when it is a plain hostname or
    #   address literal (nil otherwise); or nil for any other header,
    #   including one written with privacy mode on, which names neither
    def parse(header)
      match = header.to_s.match(/\Afrom (.+) \(\S* \[([0-9A-Fa-f:.]+)\]\) by (\S+) with SMTP; [^;]*\z/)
      return nil if match.nil?
      return nil unless match[3] == OUR_HOSTNAMES[:smtp]
      return nil unless ip_address?(match[2])

      helo = match[1]
      { helo: helo.match?(PLAIN_HELO) ? helo : nil, ip_address: match[2] }
    end

    private

    def ip_address?(value)
      IPAddr.new(value)
      true
    rescue IPAddr::InvalidAddressError
      false
    end

  end

end
