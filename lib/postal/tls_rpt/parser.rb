# frozen_string_literal: true

require "zlib"
require "stringio"
require "json"

module Postal
  module TLSRpt
    # Reads an aggregate TLS report out of the message a sender delivers to the
    # report address. Reports are supplied by third parties, so every part of the
    # message is treated as untrusted: the compressed and decompressed sizes are
    # both bounded and the JSON is only accepted if it is an object.
    class Parser

      class Error < StandardError; end

      # The largest report part which will be read, before and after inflating.
      MAX_COMPRESSED_SIZE = 1 * 1024 * 1024
      MAX_DECOMPRESSED_SIZE = 5 * 1024 * 1024

      REPORT_TYPES = ["application/tlsrpt+gzip", "application/tlsrpt+json"].freeze

      # The domain the report says it is about, from the TLS-Report-Domain
      # header. A sender is not required to set it and it is not trusted.
      attr_reader :report_domain

      # The MTA which submitted the report, from the TLS-Report-Submitter
      # header.
      attr_reader :submitter

      # Parse a raw message and return the report it carries.
      #
      # @param raw [String] the message as received
      # @return [Hash] the parsed report
      def self.parse(raw)
        new(raw).parse
      end

      def initialize(raw)
        @raw = raw
      end

      def parse
        capture_headers

        part = report_part
        raise Error, "the message does not contain a TLS report" if part.nil?

        content = part.decoded
        raise Error, "the report is larger than will be accepted" if content.bytesize > MAX_COMPRESSED_SIZE

        content = inflate(content) if part.mime_type == "application/tlsrpt+gzip"

        report = JSON.parse(content)
        raise Error, "the report is not an object" unless report.is_a?(Hash)

        report
      rescue JSON::ParserError
        raise Error, "the report is not valid JSON"
      end

      private

      # The message, read once and reused for its headers and its parts. The
      # message is written by whoever is reporting, so a message which cannot be
      # read at all is reported as a parsing failure rather than raising whatever
      # the mail library raises for it.
      def document
        return nil unless @raw.is_a?(String)

        @document ||= Mail.new(@raw)
      rescue StandardError => e
        raise Error, "the message could not be read (#{e.class})"
      end

      def capture_headers
        mail = document
        return if mail.nil?

        @report_domain = mail["TLS-Report-Domain"]&.to_s.presence
        @submitter = mail["TLS-Report-Submitter"]&.to_s.presence
      end

      # The first part of the message which carries a TLS report.
      def report_part
        mail = document
        return nil if mail.nil?

        parts = mail.all_parts.empty? ? [mail] : mail.all_parts
        parts.find { |part| REPORT_TYPES.include?(part.mime_type) }
      end

      def inflate(content)
        output = StringIO.new

        # Read one byte over the limit so that a report which expands beyond it
        # is rejected rather than silently truncated.
        reader = Zlib::GzipReader.new(StringIO.new(content))
        while (chunk = reader.read(8192))
          output.write(chunk)
          raise Error, "the report is larger than will be accepted" if output.size > MAX_DECOMPRESSED_SIZE
        end

        output.string
      rescue Zlib::Error
        raise Error, "the report could not be decompressed"
      end

    end
  end
end
