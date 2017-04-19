module Postal
  module FastServer
    class HTTPHeaderSet
      attr_accessor :headers
      def initialize
        @headers = []
      end

      def self.from_string_array(array)
        header_set = self.new
        header_set.headers = array.map{|h|HTTPHeader.from_string(h)}
        header_set
      end

      def select(key)
        @headers.select{|h|h.key.downcase == key.downcase}
      end

      def [](key)
        @headers.find{|h|h.key.downcase == key.downcase}
      end

      def []=(key, value)
        self.delete(key)
        @headers << HTTPHeader.new(key, value)
      end

      def delete(key)
        @headers.delete_if{|h|h.key.downcase == key.downcase}
      end

      def <<(header)
        @headers << header
      end
    end
  end
end
