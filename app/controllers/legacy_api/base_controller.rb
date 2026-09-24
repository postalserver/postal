# frozen_string_literal: true

module LegacyAPI
  # The Legacy API is the Postal v1 API which existed from the start with main
  # aim of allowing e-mails to sent over HTTP rather than SMTP. The API itself
  # did not feature much functionality. This API was implemented using Moonrope
  # which was a self documenting API tool, however, is now no longer maintained.
  # In light of that, these controllers now implement the same functionality as
  # the original Moonrope API without the actual requirement to use any of the
  # Moonrope components.
  #
  # Important things to note about the API:
  #
  #   * Moonrope allow params to be provided as JSON in the body of the request
  #     along with the application/json content type. It also allowed for params
  #     to be sent in the 'params' parameter when using the
  #     application/x-www-form-urlencoded content type. Both methods are supported.
  #
  #   * Authentication is performed using a X-Server-API-Key variable.
  #
  #   * The method used to make the request is not important. Most clients use POST
  #     but other methods should be supported. The routing for this legacvy
  #     API supports GET, POST, PUT and PATCH.
  #
  #   * The status code for responses will always be 200 OK. The actual status of
  #     a request is determined by the value of the 'status' attribute in the
  #     returned JSON.
  class BaseController < ActionController::Base

    skip_before_action :set_browser_id
    skip_before_action :verify_authenticity_token

    before_action :start_timer
    before_action :authenticate_as_server

    private

    # The Moonrope API spec allows for parameters to be provided in the body
    # along with the application/json content type or they can be provided,
    # as JSON, in the 'params' parameter when used with the
    # application/x-www-form-urlencoded content type. This legacy API needs
    # support both options for maximum compatibility.
    #
    # @return [Hash]
    def api_params
      if request.headers["content-type"] =~ /\Aapplication\/json/
        return params.to_unsafe_hash
      end

      if params["params"].present?
        return JSON.parse(params["params"])
      end

      {}
    end

    # The API returns a length of time to complete a request. We'll start
    # a timer when the request starts and then use this method to calculate
    # the time taken to complete the request.
    #
    # @return [void]
    def start_timer
      @start_time = Time.now.to_f
    end

    # The only method available to authenticate to the legacy API is using a
    # credential from the server itself. This method will attempt to find
    # that credential from the X-Server-API-Key header and will set the
    # current_credential instance variable if a token is valid. Otherwise it
    # will render an error to halt execution.
    #
    # Attempts are counted against the calling address so that a client guessing
    # keys is refused rather than allowed to guess indefinitely.
    #
    # @return [void]
    def authenticate_as_server
      if api_authentication_rate_limited?
        response.headers["Retry-After"] = Postal::Config.protection.api_auth_failures_period.to_s
        render_error "RateLimited",
                     message: "Too many failed authentication attempts. Please try again later."
        return
      end

      key = request.headers["X-Server-API-Key"]
      if key.blank?
        render_error "AccessDenied",
                     message: "Must be authenticated as a server."
        return
      end

      credential = Credential.where(type: "API", key: key).first
      if credential.nil?
        render_error "InvalidServerAPIKey",
                     message: "The API token provided in X-Server-API-Key was not valid."
        return
      end

      if credential.server.suspended?
        render_error "ServerSuspended"
        return
      end

      Postal::RateLimiter.clear(api_authentication_key)
      credential.use
      @current_credential = credential
    end

    # Count one use against this credential's send quota and refuse when it is
    # spent. Quotas default to unlimited, so this is a no-op until configured.
    # Call after authentication, before doing the work.
    #
    # @return [Boolean] true when the request was refused
    def api_quota_exceeded?
      result = Postal::RateLimiter.check_quota(:api_send, @current_credential)
      return false unless result.exceeded?

      quota_exceeded!("Too many API requests for this credential. Please try again later.", result.retry_after)
      true
    end

    # Refuse with the same shape as the authentication limiter, quoting the
    # quota's own retry delay, and record the refusal for observability.
    #
    # @return [void]
    def quota_exceeded!(message, retry_after)
      response.headers["Retry-After"] = retry_after.to_s
      Postal::Telemetry.increment("postal_quota_exceeded_total", type: "api")
      Postal::Metrics.record("postal_quota_exceeded_total", { type: "api" }, 1)
      render_error "RateLimited", message: message
    end

    # Count this authentication attempt against the calling address and report
    # whether its allowance has been spent.
    #
    # @return [Boolean]
    def api_authentication_rate_limited?
      Postal::RateLimiter.exceeded?(api_authentication_key,
                                    limit: Postal::Config.protection.api_auth_failures_limit,
                                    period: Postal::Config.protection.api_auth_failures_period)
    end

    # @return [String]
    def api_authentication_key
      "api-auth:#{request.remote_ip}"
    end

    # Render a successful response to the client
    #
    # @param [Hash] data
    # @return [void]
    def render_success(data)
      render json: { status: "success",
                     time: (Time.now.to_f - @start_time).round(3),
                     flags: {},
                     data: data }
    end

    # Render an error response to the client
    #
    # @param [String] code
    # @param [Hash] data
    # @return [void]
    def render_error(code, data = {})
      render json: { status: "error",
                     time: (Time.now.to_f - @start_time).round(3),
                     flags: {},
                     data: data.merge(code: code) }
    end

    # Render a parameter error response to the client
    #
    # @param [String] message
    # @return [void]
    def render_parameter_error(message)
      render json: { status: "parameter-error",
                     time: (Time.now.to_f - @start_time).round(3),
                     flags: {},
                     data: { message: message } }
    end

  end
end
