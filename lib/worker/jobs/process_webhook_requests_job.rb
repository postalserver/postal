# frozen_string_literal: true

module Worker
  module Jobs
    class ProcessWebhookRequestsJob < BaseJob

      def call
        @lock_time = Time.current
        @locker = Postal.locker_name_with_suffix(SecureRandom.hex(8))

        lock_request_for_processing
        obtain_locked_requests
        process_requests
      end

      private

      # Obtain a webhook request from the database for processing
      #
      # @return [void]
      def lock_request_for_processing
        WebhookRequest.unlocked
                      .ready
                      .limit(1)
                      .update_all(locked_by: @locker, locked_at: @lock_time)
      end

      # Get a full list of all webhooks which we can process (i.e. those which have just
      # been locked by us for processing)
      #
      # @return [void]
      def obtain_locked_requests
        @requests_to_process = WebhookRequest.where(locked_by: @locker, locked_at: @lock_time)
      end

      # Process the webhook requests we obtained from the database
      #
      # @return [void]
      def process_requests
        @requests_to_process.each do |request|
          work_completed!

          WebhookDeliveryService.new(webhook_request: request).call
        end
      end

    end
  end
end
