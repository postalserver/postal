module Postal
  class ReceivedHeader

    OUR_HOSTNAMES = {
      smtp: Postal.config.dns.smtp_server_hostname,
      http: Postal.config.web.host
    }

    class << self

      def generate(server, helo, ip_address, method)
        our_hostname = OUR_HOSTNAMES[method]
        if our_hostname.nil?
          raise Error, "`method` is invalid (must be one of #{OUR_HOSTNAMES.join(', ')})"
        end

        header = "by #{our_hostname} with #{method.to_s.upcase}; #{Time.now.utc.rfc2822}"

        if server.nil? || server.privacy_mode == false
          hostname = resolve_hostname(ip_address)
          header = "from #{helo} (#{hostname} [#{ip_address}]) #{header}"
        end

        header
      end

      private

      def resolve_hostname(ip_address)
        Resolv::DNS.open do |dns|
          dns.timeouts = [10, 5]
          begin
            dns.getname(ip_address)
          rescue StandardError
            ip_address
          end
        end
      end

    end

  end
end
