# frozen_string_literal: true

module Postal

  class Error < StandardError
  end

  module Errors
    class AuthenticationError < Error

      attr_reader :error

      def initialize(error)
        super()
        @error = error
      end

      def to_s
        "Authentication Failed: #{@error}"
      end

    end
  end

end
