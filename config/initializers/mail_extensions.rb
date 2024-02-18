# frozen_string_literal: true

require "mail"
module Mail

  module Encodings

    # Handle windows-1258 as windows-1252 when decoding
    def self.q_value_decode(str)
      str = str.sub(/=\?windows-?1258\?/i, '\=?windows-1252?')
      Utilities.q_value_decode(str)
    end

    def self.b_value_decode(str)
      str = str.sub(/=\?windows-?1258\?/i, '\=?windows-1252?')
      Utilities.b_value_decode(str)
    end

  end

  class Message

    ## Extract plain text body of message
    def plain_body
      if multipart? && text_part
        text_part.decoded
      elsif mime_type == "text/plain" || mime_type.nil?
        decoded
      end
    end

    ## Extract HTML text body of message
    def html_body
      if multipart? && html_part
        html_part.decoded
      elsif mime_type == "text/html"
        decoded
      end
    end

    private

    ## Fix bug in basic parsing
    def parse_message
      self.header, self.body = raw_source.split(/\r?\n\r?\n/m, 2)
    end

    # Handle attached emails as attachments
    # Returns the filename of the attachment (if it exists) or returns nil
    # Make up a filename for rfc822 attachments if it isn't specified
    def find_attachment
      content_type_name = begin
        header[:content_type].filename
      rescue StandardError
        nil
      end
      content_disp_name = begin
        header[:content_disposition].filename
      rescue StandardError
        nil
      end
      content_loc_name = begin
        header[:content_location].location
      rescue StandardError
        nil
      end

      if content_type && content_type_name
        filename = content_type_name
      elsif content_disposition && content_disp_name
        filename = content_disp_name
      elsif content_location && content_loc_name
        filename = content_loc_name
      elsif mime_type == "message/rfc822"
        filename = "#{rand(100_000_000)}.eml"
      else
        filename = nil
      end

      if filename
        # Normal decode
        filename = begin
          Mail::Encodings.decode_encode(filename, :decode)
        rescue StandardError
          filename
        end
      end
      filename
    end

    def decode_body_as_text
      body_text = decode_body
      charset_tmp = begin
        Encoding.find(Utilities.pick_encoding(charset))
      rescue StandardError
        "ASCII"
      end
      charset_tmp = "Windows-1252" if charset_tmp.to_s =~ /windows-?1258/i
      if charset_tmp == Encoding.find("UTF-7")
        body_text.force_encoding("UTF-8")
        decoded = body_text.gsub(/\+.*?-/m) { |n| Base64.decode64(n[1..-2] + "===").force_encoding("UTF-16BE").encode("UTF-8") }
      else
        body_text.force_encoding(charset_tmp)
        decoded = body_text.encode("utf-8", invalid: :replace, undef: :replace)
      end
      decoded.valid_encoding? ? decoded : decoded.encode("utf-16le", invalid: :replace, undef: :replace).encode("utf-8")
    end

  end

  # Handle attached emails as attachments
  class AttachmentsList < Array

    # rubocop:disable Lint/MissingSuper
    def initialize(parts_list)
      @parts_list = parts_list
      @content_disposition_type = "attachment"
      parts = parts_list.map do |p|
        p.parts.empty? && p.attachment? ? p : p.attachments
      end.flatten.compact
      parts.each { |a| self << a }
    end
    # rubocop:enable Lint/MissingSuper

  end

end

class Array

  def decoded
    return nil if empty?

    first.decoded
  end

end

class NilClass

  def decoded
    nil
  end

end
