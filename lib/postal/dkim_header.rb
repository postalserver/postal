module Postal
  class DKIMHeader

    def initialize(domain, message)
      if domain && domain.dkim_status == 'OK'
        @domain_name = domain.name
        @dkim_key = domain.dkim_key
        @dkim_identifier = domain.dkim_identifier
      else
        @domain_name = Postal.config.dns.return_path
        @dkim_key = Postal.signing_key
        @dkim_identifier = 'postal'
      end
      @domain = domain
      @message = message
      @raw_headers, @raw_body = @message.split(/\r?\n\r?\n/, 2)
    end

    def dkim_header
      "DKIM-Signature: v=1;" + dkim_properties + signature
    end

    private

    def headers
      @headers ||= @raw_headers.to_s.gsub(/\r?\n\s/, ' ').split(/\r?\n/)
    end

    def header_names
      normalized_headers.map{ |h| h.split(':')[0].strip }
    end

    def normalized_headers
      Array.new.tap do |new_headers|
        headers.select { |h| h.match(/^(from|sender|reply-to|subject|date|message-id|to|cc|mime-version|content-type|content-transfer-encoding|resent-to|resent-cc|resent-from|resent-sender|resent-message-id|in-reply-to|references|list-id|list-help|list-owner|list-unsubscribe|list-subscribe|list-post):/i) }.each do |h|
          new_headers << normalize_header(h)
        end
      end
    end

    def normalize_header(content)
      content.gsub!(/[ \t]+/, ' ')                          # Tidy whitespace
      key, value = content.split(':', 2).map{ |a| a.strip } # Split into key/value and strip whitespace
      key.downcase!                                         # Downcase the key
      key + ':' + value                                     # Rejoin
    end

    def normalized_body
      @normalized_body ||= begin
        content = @raw_body.dup
        content.gsub!("\r", '')         # Make sure we have no random CRs
        content.gsub!("\n", "\r\n")     # Convert to CRLF
        content.gsub!(/[ \t]+/, ' ')    # Tidy whitespace
        content.gsub!(" \r\n", "\r\n")  # Remove trailing whitespace
        content.gsub!(/(\r\n)+\z/, "")  # Remove trailing lines
        content.gsub!(/\z/, "\r\n")     # Add a final newline
        content
      end
    end

    def body_hash
      @body_hash ||= Base64.encode64(Digest::SHA256.digest(normalized_body)).strip
    end

    def dkim_properties
      String.new.tap do |header|
        header << " a=rsa-sha256; c=relaxed/relaxed;"
        header << " d=#{@domain_name}; s=#{@dkim_identifier}; t=#{Time.now.utc.to_i};"
        header << " bh=#{body_hash}; h=#{header_names.join(':')};"
        header << " b="
      end
    end

    def dkim_header_for_signing
      "dkim-signature:v=1;" + dkim_properties
    end

    def signable_header_string
      (normalized_headers + [dkim_header_for_signing]).join("\r\n")
    end

    def signature
      Base64.encode64(@dkim_key.sign(OpenSSL::Digest::SHA256.new, signable_header_string)).gsub("\n", '')
    end

  end
end
