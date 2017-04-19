module Postal
  module FastServer
    class HTTPHeader
      attr_accessor :key, :value
      def self.from_string(string)
        k, v = string.to_s.split(/\:\s*/, 2)
        self.new(k.to_s, v.to_s)
      end

      def initialize(k, v)
        @key = k
        @value = v
      end

      def to_s
        @key + ": " + @value
      end
    end

  end
end
