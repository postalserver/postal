# frozen_string_literal: true

require "net/https"
require "resolv"
require "uri"

module Postal
  module HTTP

    def self.get(url, options = {})
      request(Net::HTTP::Get, url, options)
    end

    def self.post(url, options = {})
      request(Net::HTTP::Post, url, options)
    end

    def self.request(method, url, options = {})
      options[:headers] ||= {}
      uri = URI.parse(url)
      request = method.new((uri.path.empty? ? "/" : uri.path) + (uri.query ? "?" + uri.query : ""))
      options[:headers].each { |k, v| request.add_field k, v }

      if options[:username] || uri.user
        request.basic_auth(options[:username] || uri.user, options[:password] || uri.password)
      end

      if options[:params].is_a?(Hash)
        # If params has been provided, sent it them as form encoded values
        request.set_form_data(options[:params])

      elsif options[:json].is_a?(String)
        # If we have a JSON string, set the content type and body to be the JSON
        # data
        request.add_field "Content-Type", "application/json"
        request.body = options[:json]

      elsif options[:text_body]
        # Add a plain text body if we have one
        request.body = options[:text_body]
      end

      if options[:sign]
        request.add_field "X-Postal-Signature-KID", Postal.signer.jwk.kid
        request.add_field "X-Postal-Signature", Postal.signer.sha1_sign64(request.body.to_s)
        request.add_field "X-Postal-Signature-256", Postal.signer.sign64(request.body.to_s)
      end

      request["User-Agent"] = options[:user_agent] || "Postal/#{Postal.version}"

      timeout = options[:timeout] || 60
      ssl = uri.scheme == "https"

      begin
        Timeout.timeout(timeout) do
          connect_address = AddressGuard.safe_connect_address(uri.host)

          connection = Net::HTTP.new(uri.host, uri.port)
          # Pin the connection to the address we validated above so that the socket
          # cannot be redirected to a different (e.g. internal) address via a DNS
          # rebinding race between the check and the connection.
          connection.ipaddr = connect_address

          if uri.scheme == "https"
            connection.use_ssl = true
            connection.verify_mode = OpenSSL::SSL::VERIFY_PEER
          end

          result = connection.request(request)
          {
            code: result.code.to_i,
            body: result.body,
            headers: result.to_hash,
            secure: ssl
          }
        end
      rescue BlockedDestinationError => e
        {
          code: -4,
          body: e.message,
          headers: {},
          secure: ssl
        }
      rescue OpenSSL::SSL::SSLError
        {
          code: -3,
          body: "Invalid SSL certificate",
          headers: {},
          secure: ssl
        }
      rescue Resolv::ResolvError, SocketError, SystemCallError, EOFError => e
        {
          code: -2,
          body: e.message,
          headers: {},
          secure: ssl
        }
      rescue Timeout::Error
        {
          code: -1,
          body: "Timed out after #{timeout}s",
          headers: {},
          secure: ssl
        }
      end
    end

  end
end
