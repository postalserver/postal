# frozen_string_literal: true

module API
  module V2
    module Idempotency

      private

      def with_idempotency
        key = request.headers["Idempotency-Key"].to_s
        return yield if key.blank?
        return render_error("invalid_idempotency_key", "Idempotency-Key must be at most 255 characters", status: :bad_request) if key.length > 255

        digest = Digest::SHA256.hexdigest([request.request_method, request.path, request.raw_post].join("\n"))
        record, created = reserve_idempotency_record(key, digest)
        return replay_idempotency_record(record, digest) unless created

        yield
        record.update!(response_status: response.status, response_body: response.body)
      rescue StandardError
        record&.destroy! if created && record&.persisted? && record.response_status.nil?
        raise
      end

      def reserve_idempotency_record(key, digest)
        record = current_control_api_key.idempotency_records.create!(
          key: key, request_method: request.request_method, request_path: request.path, payload_digest: digest
        )
        [record, true]
      rescue ActiveRecord::RecordNotUnique
        [current_control_api_key.idempotency_records.find_by!(key: key), false]
      end

      def replay_idempotency_record(record, digest)
        return render_error("idempotency_conflict", "Idempotency-Key was reused with a different request", status: :conflict) if record.payload_digest != digest
        return render_error("idempotency_in_progress", "A request with this Idempotency-Key is still being processed", status: :conflict) if record.response_status.nil?

        return head(record.response_status) if record.response_body.blank?

        render json: JSON.parse(record.response_body), status: record.response_status
      end

    end
  end
end
