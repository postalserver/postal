# frozen_string_literal: true

module API
  module V2
    class BaseController < ActionController::API

      include Idempotency

      # Authie extends ActionController::API globally. Bearer-authenticated
      # control requests deliberately do not create browser sessions/cookies.
      skip_before_action :set_browser_id, raise: false
      skip_before_action :validate_auth_session, raise: false
      prepend_before_action :skip_touch_auth_session!

      MAX_PAGE_SIZE = 100
      DEFAULT_PAGE_SIZE = 25
      RATE_LIMIT = 300
      RATE_LIMIT_WINDOW = 5.minutes

      before_action :set_request_id
      before_action :authenticate_control_api_key!
      before_action :enforce_rate_limit!

      rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
      rescue_from ActionController::ParameterMissing, with: :parameter_missing
      rescue_from ActionController::UnpermittedParameters, with: :unpermitted_parameters
      rescue_from ActiveRecord::RecordInvalid, with: :record_invalid

      private

      attr_reader :current_control_api_key

      def authenticate_control_api_key!
        header = request.authorization.to_s
        token = header[/\ABearer\s+([^\s]+)\z/i, 1]
        return render_error("unauthorized", "A bearer token is required", status: :unauthorized) unless token

        @current_control_api_key = ControlAPIKey.authenticate(token)
        render_error("unauthorized", "The bearer token is invalid, expired, or revoked", status: :unauthorized) unless @current_control_api_key
      end

      def require_scope!(scope)
        return if current_control_api_key&.allows?(scope)

        render_error("forbidden", "This API key does not have the required scope", status: :forbidden)
      end

      def organization_scope!(organization)
        return true if current_control_api_key.platform_admin?
        return true if current_control_api_key.organization_id == organization.id

        render_error("not_found", "The requested resource could not be found", status: :not_found)
        false
      end

      def scoped_organization!(uuid = params[:organization_uuid] || params[:uuid])
        organization = Organization.present.find_by!(uuid: uuid)
        organization_scope!(organization) ? organization : nil
      end

      def render_data(data, status: :ok, meta: nil)
        body = { data: data, meta: meta || {}, error: nil }
        response.set_header("X-Request-Id", request_id)
        render json: body, status: status
      end

      def render_error(code, message, status:, details: {})
        response.set_header("X-Request-Id", request_id)
        render json: { data: nil, meta: {}, error: { code: code, message: message, details: details } }, status: status
      end

      def pagination_for(scope)
        page = [params.fetch(:page, 1).to_i, 1].max
        per_page = params.fetch(:per_page, DEFAULT_PAGE_SIZE).to_i.clamp(1, MAX_PAGE_SIZE)
        [scope.offset((page - 1) * per_page).limit(per_page), { page: page, per_page: per_page }]
      end

      def audit!(organization:, resource:, action:, before: {}, after: {})
        AuditEvent.create!(actor_uuid: current_control_api_key.uuid, organization_uuid: organization.uuid,
                           resource_type: resource.class.name, resource_uuid: resource.uuid, action: action,
                           request_id: request_id, source_ip: request.remote_ip,
                           before_metadata: safe_metadata(before), after_metadata: safe_metadata(after), occurred_at: Time.current)
      end

      attr_reader :request_id

      def set_request_id
        @request_id = request.headers["X-Request-Id"].presence || SecureRandom.uuid
      end

      def enforce_rate_limit!
        key = "control-api-rate-limit/#{current_control_api_key.uuid}/#{Time.current.to_i / RATE_LIMIT_WINDOW.to_i}"
        count = Rails.cache.increment(key, 1, expires_in: RATE_LIMIT_WINDOW)
        return if count <= RATE_LIMIT

        render_error("rate_limited", "Too many requests", status: :too_many_requests)
      end

      def record_not_found
        render_error("not_found", "The requested resource could not be found", status: :not_found)
      end

      def parameter_missing(exception)
        render_error("invalid_request", "A required parameter is missing", status: :bad_request, details: { parameter: exception.param })
      end

      def unpermitted_parameters(exception)
        render_error("invalid_request", "The request contains unsupported parameters", status: :unprocessable_content, details: { parameters: exception.params })
      end

      def record_invalid(exception)
        render_error("validation_failed", "The request could not be processed", status: :unprocessable_content, details: exception.record.errors.to_hash)
      end

      def safe_metadata(value)
        filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(value.to_h)
        JSON.parse(JSON.generate(filtered))
      end

    end
  end
end
