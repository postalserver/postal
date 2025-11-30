# frozen_string_literal: true

module ManagementAPI
  module V2
    class BaseController < ActionController::API

      before_action :start_timer
      before_action :authenticate

      rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
      rescue_from ActionController::ParameterMissing, with: :parameter_missing

      protected

      attr_reader :current_api_key

      def require_super_admin!
        return if current_api_key&.super_admin?

        render_error("Forbidden", "This operation requires super admin privileges", status: :forbidden)
      end

      def find_organization!(permalink_param = :org_permalink)
        permalink = params[permalink_param]
        @organization = current_api_key.accessible_organizations.find_by!(permalink: permalink)
      end

      def find_server!(uuid_param = :server_uuid)
        uuid = params[uuid_param]
        scope = current_api_key.super_admin? ? Server : Server.where(organization: current_api_key.accessible_organizations)
        @server = scope.find_by!(uuid: uuid)
      end

      def render_success(data, meta: nil, status: :ok)
        response = {
          status: "success",
          time: elapsed_time,
          data: data
        }
        response[:meta] = meta if meta.present?
        render json: response, status: status
      end

      def render_error(code, message, status: :bad_request, details: nil)
        response = {
          status: "error",
          time: elapsed_time,
          error: {
            code: code,
            message: message
          }
        }
        response[:error][:details] = details if details.present?
        render json: response, status: status
      end

      def paginate(collection, default_per_page: 25, max_per_page: 100)
        page = [params[:page].to_i, 1].max
        per_page = [[params[:per_page].to_i, default_per_page].max, max_per_page].min
        per_page = default_per_page if params[:per_page].blank?

        total = collection.count
        total_pages = (total.to_f / per_page).ceil

        paginated = collection.offset((page - 1) * per_page).limit(per_page)

        meta = {
          page: page,
          per_page: per_page,
          total: total,
          total_pages: total_pages
        }

        [paginated, meta]
      end

      private

      def start_timer
        @start_time = Time.now.to_f
      end

      def elapsed_time
        (Time.now.to_f - @start_time).round(4)
      end

      def authenticate
        key_value = extract_api_key
        if key_value.blank?
          render_error("AuthenticationRequired", "API key is required", status: :unauthorized)
          return
        end

        # Check config-based API key first
        if config_api_key_valid?(key_value)
          @current_api_key = ConfigBasedApiKey.new
          return
        end

        # Check database-stored API keys
        @current_api_key = ManagementAPIKey.authenticate(key_value)
        if @current_api_key.nil?
          render_error("InvalidApiKey", "The provided API key is invalid or has expired", status: :unauthorized)
          return
        end

        @current_api_key.use!(request.remote_ip)
      end

      def config_api_key_valid?(key_value)
        config_key = Postal::Config.management_api&.api_key
        return false if config_key.blank?

        ActiveSupport::SecurityUtils.secure_compare(config_key, key_value)
      end

      # Virtual API key class for config-based authentication
      class ConfigBasedApiKey
        def uuid
          "config-api-key"
        end

        def name
          "Config API Key"
        end

        def super_admin?
          true
        end

        def can_access_organization?(_org)
          true
        end

        def accessible_organizations
          Organization.present
        end

        def use!(_ip = nil)
          # No-op for config-based keys
        end
      end

      def extract_api_key
        # Check X-Management-API-Key header first
        key = request.headers["X-Management-API-Key"]
        return key if key.present?

        # Check Authorization: Bearer header
        auth_header = request.headers["Authorization"]
        if auth_header.present? && auth_header.start_with?("Bearer ")
          return auth_header.sub("Bearer ", "")
        end

        nil
      end

      def record_not_found(exception)
        model_name = exception.model || "Resource"
        render_error("NotFound", "#{model_name} not found", status: :not_found)
      end

      def record_invalid(exception)
        render_error(
          "ValidationError",
          "Validation failed",
          status: :unprocessable_entity,
          details: exception.record.errors.to_hash
        )
      end

      def parameter_missing(exception)
        render_error(
          "ParameterMissing",
          "Required parameter missing: #{exception.param}",
          status: :bad_request
        )
      end

    end
  end
end
