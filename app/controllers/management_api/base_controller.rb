# frozen_string_literal: true

module ManagementAPI
  # Management API for Postal - provides full administrative control
  # over organizations, servers, domains, credentials and webhooks.
  #
  # Authentication is performed using X-Management-API-Key header.
  # The API key should be configured in postal.yml under management_api.key
  #
  # Example usage:
  #   curl -X POST https://postal.example.com/management/api/v1/servers \
  #     -H "X-Management-API-Key: your-secret-key" \
  #     -H "Content-Type: application/json" \
  #     -d '{"organization": "my-org", "name": "Transactional", "ip_pool_id": 1}'
  #
  class BaseController < ActionController::Base

    skip_before_action :set_browser_id, raise: false
    skip_before_action :verify_authenticity_token, raise: false

    before_action :start_timer
    before_action :authenticate_management_api

    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_validation_error

    private

    def start_timer
      @start_time = Time.now.to_f
    end

    # Authenticate using X-Management-API-Key header
    # The key is configured in postal.yml or via MANAGEMENT_API_KEY env var
    def authenticate_management_api
      # Check if Management API is enabled
      unless management_api_enabled?
        render_error "Disabled", message: "Management API is disabled in configuration"
        return
      end

      key = request.headers["X-Management-API-Key"]

      if key.blank?
        render_error "AccessDenied", message: "X-Management-API-Key header is required"
        return
      end

      expected_key = management_api_key
      if expected_key.blank?
        render_error "NotConfigured", message: "Management API key is not configured. Set management_api.key in postal.yml or POSTAL_MANAGEMENT_API_KEY env var."
        return
      end

      unless ActiveSupport::SecurityUtils.secure_compare(key, expected_key)
        render_error "InvalidAPIKey", message: "The provided API key is invalid"
        return
      end
    end

    def management_api_enabled?
      # Default to true if config section doesn't exist
      return true unless Postal::Config.respond_to?(:management_api)
      return true unless Postal::Config.management_api.respond_to?(:enabled?)

      Postal::Config.management_api.enabled?
    end

    def management_api_key
      # Try environment variable first, then config
      ENV["POSTAL_MANAGEMENT_API_KEY"] ||
        (Postal::Config.respond_to?(:management_api) && Postal::Config.management_api.respond_to?(:key) ? Postal::Config.management_api.key : nil)
    end

    def api_params
      if request.headers["content-type"] =~ /\Aapplication\/json/
        return params.to_unsafe_hash.with_indifferent_access
      end
      params.to_unsafe_hash.with_indifferent_access
    end

    def render_success(data)
      render json: {
        status: "success",
        time: elapsed_time,
        data: data
      }
    end

    def render_error(code, data = {})
      render json: {
        status: "error",
        time: elapsed_time,
        data: data.merge(code: code)
      }, status: :unprocessable_entity
    end

    def render_not_found(exception)
      render json: {
        status: "error",
        time: elapsed_time,
        data: { code: "NotFound", message: exception.message }
      }, status: :not_found
    end

    def render_validation_error(exception)
      render json: {
        status: "error",
        time: elapsed_time,
        data: {
          code: "ValidationError",
          message: exception.message,
          errors: exception.record.errors.to_hash
        }
      }, status: :unprocessable_entity
    end

    def elapsed_time
      (Time.now.to_f - @start_time).round(3)
    end

    # Helper to find organization by permalink
    def find_organization(permalink)
      Organization.find_by!(permalink: permalink)
    end

    # Helper to find server by org/server format or by id
    def find_server(identifier)
      if identifier.to_s.include?("/")
        Server[identifier]
      else
        Server.find(identifier)
      end
    end

  end
end
