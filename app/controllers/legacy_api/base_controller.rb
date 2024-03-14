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
    # @return [void]
    def authenticate_as_server
      key = request.headers["X-Server-API-Key"]
      if key.blank?
        render_error "AccessDenied",
                     message: "Must be authenticated as a server."
        return
      end

      credential = Credential.where(type: "API", key: key).first
      if credential.nil?
        render_error "InvalidServerAPIKey",
                     message: "The API token provided in X-Server-API-Key was not valid.",
                     token: key
        return
      end

      if credential.server.suspended?
        render_error "ServerSuspended"
        return
      end

      credential.use
      @current_credential = credential
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
