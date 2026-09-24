# frozen_string_literal: true

class ReceivedHeader

  OUR_HOSTNAMES = {
    smtp: Postal::Config.postal.smtp_hostname,
    http: Postal::Config.postal.web_hostname
  }.freeze

  class << self

    def generate(server, helo, ip_address, method, smtputf8: false)
      our_hostname = OUR_HOSTNAMES[method]
      if our_hostname.nil?
        raise Error, "`method` is invalid (must be one of #{OUR_HOSTNAMES.join(', ')})"
      end

      # RFC 6531 section 3.7.3: a message which arrived over an internationalised
      # session says so in the protocol name.
      protocol = smtputf8 ? "SMTPUTF8" : method.to_s.upcase

      header = "by #{our_hostname} with #{protocol}; #{Time.now.utc.rfc2822}"

      if server.nil? || server.privacy_mode == false
        hostname = DNSResolver.local.ip_to_hostname(ip_address)
        header = "from #{helo} (#{hostname} [#{ip_address}]) #{header}"
      end

      header
    end

  end

end
