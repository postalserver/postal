# frozen_string_literal: true

module ManagementAPI
  # Management API v2 - RESTful API for full Postal management automation.
  #
  # Features:
  #   * RESTful JSON API design
  #   * Authentication via X-Management-API-Key header
  #   * Permission-based access control
  #   * Rate limiting support
  #   * Detailed error responses
  #
  class BaseController < ActionController::Base

    skip_before_action :set_browser_id if respond_to?(:skip_before_action)
    skip_before_action :verify_authenticity_token

    before_action :start_timer
    before_action :authenticate
    before_action :check_rate_limit

    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_validation_error
    rescue_from ActionController::ParameterMissing, with: :render_parameter_missing

    protected

    attr_reader :current_api_key

    # Parse JSON parameters
    def api_params
      @api_params ||= if request.content_type&.include?("application/json") && request.body.present?
        request.body.rewind
        body = request.body.read
        body.present? ? JSON.parse(body).with_indifferent_access : {}
      else
        params.to_unsafe_hash.with_indifferent_access
      end
    rescue JSON::ParserError
      {}
    end

    private

    def start_timer
      @start_time = Time.now.to_f
    end

    def authenticate
      key = request.headers["X-Management-API-Key"] || request.headers["Authorization"]&.gsub(/^Bearer\s+/, "")

      if key.blank?
        render_error("AuthenticationRequired", "API key is required. Provide X-Management-API-Key header.", 401)
        return
      end

      # First, check if key matches the static key from postal.yml config
      if Postal::Config.management_api.key.present? && ActiveSupport::SecurityUtils.secure_compare(key, Postal::Config.management_api.key)
        @current_api_key = StaticManagementAPIKey.new(Postal::Config.management_api.super_admin?)
        return
      end

      # Fall back to database-stored keys
      @current_api_key = ManagementAPIKey.authenticate(key)

      if @current_api_key.nil?
        render_error("InvalidApiKey", "The provided API key is invalid or has expired.", 401)
        return
      end

      @current_api_key.use(request.remote_ip)
    end

    def check_rate_limit
      # Rate limiting can be implemented here
      # For now, we'll skip it but the structure is in place
      true
    end

    def authorize!(resource, action)
      return if current_api_key.can?(resource, action)

      render_error(
        "Forbidden",
        "You don't have permission to #{action} #{resource}.",
        403
      )
    end

    def require_super_admin!
      return if current_api_key.super_admin?

      render_error("Forbidden", "This action requires super admin privileges.", 403)
    end

    # Response helpers

    def render_success(data, status: :ok, meta: {})
      response_body = {
        status: "success",
        time: elapsed_time,
        data: data
      }
      response_body[:meta] = meta if meta.present?

      render json: response_body, status: status
    end

    def render_created(data, location: nil)
      response_body = {
        status: "success",
        time: elapsed_time,
        data: data
      }

      headers["Location"] = location if location
      render json: response_body, status: :created
    end

    def render_deleted
      render json: {
        status: "success",
        time: elapsed_time,
        data: { deleted: true }
      }, status: :ok
    end

    def render_error(code, message, http_status = 400)
      render json: {
        status: "error",
        time: elapsed_time,
        error: {
          code: code,
          message: message
        }
      }, status: http_status
    end

    def render_not_found(exception = nil)
      message = exception&.message || "Resource not found"
      render_error("NotFound", message, 404)
    end

    def render_validation_error(exception)
      render json: {
        status: "error",
        time: elapsed_time,
        error: {
          code: "ValidationError",
          message: "Validation failed",
          details: exception.record.errors.to_hash
        }
      }, status: :unprocessable_entity
    end

    def render_parameter_missing(exception)
      render_error("ParameterMissing", exception.message, 400)
    end

    def elapsed_time
      (Time.now.to_f - @start_time).round(4)
    end

    # Pagination helpers

    def paginate(scope)
      page = (api_params[:page] || 1).to_i
      per_page = [(api_params[:per_page] || 25).to_i, 100].min

      total = scope.count
      records = scope.offset((page - 1) * per_page).limit(per_page)

      {
        records: records,
        meta: {
          page: page,
          per_page: per_page,
          total: total,
          total_pages: (total.to_f / per_page).ceil
        }
      }
    end

  end
end
