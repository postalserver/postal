# frozen_string_literal: true

module Worker
  module Jobs
    class BaseJob

      def initialize(logger:)
        @logger = logger
      end

      def call
        # Override me.
      end

      def work_completed?
        @work_completed == true
      end

      private

      def work_completed!
        @work_completed = true
      end

      attr_reader :logger

    end
  end
end
