# frozen_string_literal: true

class SessionsController < ApplicationController

  layout "sub"

  before_action :require_local_authentication, only: [:create, :begin_password_reset, :finish_password_reset]
  skip_before_action :login_required, only: [:new, :create, :begin_password_reset, :finish_password_reset, :ip, :raise_error, :create_from_oidc, :oauth_failure]

  def create
    if login_rate_limited?
      flash.now[:alert] = "Too many failed login attempts. Please try again later."
      render "new"
      return
    end

    login(User.authenticate(params[:email_address], params[:password]))
    clear_login_attempts
    flash[:remember_login] = true
    redirect_to_with_return_to root_path
  rescue Postal::Errors::AuthenticationError
    flash.now[:alert] = "The credentials you've provided are incorrect. Please check and try again."
    render "new"
  end

  def destroy
    auth_session.invalidate! if logged_in?
    reset_session
    redirect_to login_path
  end

  def persist
    auth_session.persist! if logged_in?
    render plain: "OK"
  end

  def begin_password_reset
    return unless request.post?

    if password_reset_rate_limited?
      redirect_to login_reset_path(return_to: params[:return_to]), alert: "Too many password reset requests. Please try again later."
      return
    end

    user_scope = Postal::Config.oidc.enabled? ? User.with_password : User
    user = user_scope.find_by(email_address: params[:email_address])

    if user.nil?
      # Deliberately the same response as a request which did match. Saying that no
      # account exists would turn this form into a way of finding out which
      # addresses have accounts, one address at a time, which no amount of rate
      # limiting makes acceptable.
      redirect_to login_path(return_to: params[:return_to]), notice: "Please check your e-mail and click the link in the e-mail we've sent you."
      return
    end

    user.begin_password_reset(params[:return_to])
    redirect_to login_path(return_to: params[:return_to]), notice: "Please check your e-mail and click the link in the e-mail we've sent you."
  end

  def finish_password_reset
    if reset_redeem_rate_limited?
      redirect_to login_path(return_to: params[:return_to]), alert: "Too many password reset attempts. Please try again later."
      return
    end

    @user = User.where(password_reset_token: params[:token]).where("password_reset_token_valid_until > ?", Time.now).first
    if @user.nil?
      redirect_to login_path(return_to: params[:return_to]), alert: "This link has expired or never existed. Please choose reset password to try again."
      return
    end

    return unless request.post?

    if params[:password].blank?
      flash.now[:alert] = "You must enter a new password"
      return
    end

    @user.password = params[:password]
    @user.password_confirmation = params[:password_confirmation]
    return unless @user.save

    login(@user)
    redirect_to_with_return_to root_path, notice: "Your new password has been set and you've been logged in."
  end

  def ip
    render plain: "ip: #{request.ip} remote ip: #{request.remote_ip}"
  end

  def create_from_oidc
    unless Postal::Config.oidc.enabled?
      raise Postal::Error, "OIDC cannot be used unless enabled in the configuration"
    end

    auth = request.env["omniauth.auth"]
    user = User.find_from_oidc(auth.extra.raw_info, logger: Postal.logger)
    if user.nil?
      redirect_to login_path, alert: "No user was found matching your identity. Please contact your administrator."
      return
    end

    login(user)
    flash[:remember_login] = true
    redirect_to_with_return_to root_path
  end

  def oauth_failure
    redirect_to login_path, alert: "An issue occurred while logging you in with OpenID. Please try again later or contact your administrator."
  end

  private

  # Count this login attempt and report whether either allowance has been
  # spent: one key limits guessing at a single account, the other limits a
  # client spraying one password across many accounts.
  #
  # @return [Boolean]
  def login_rate_limited?
    Postal::RateLimiter.check(login_ip_key,
                              limit: Postal::Config.protection.web_login_failures_limit,
                              period: Postal::Config.protection.web_login_failures_period).exceeded? ||
      Postal::RateLimiter.check(login_address_key,
                                limit: Postal::Config.protection.web_login_failures_limit,
                                period: Postal::Config.protection.web_login_failures_period).exceeded?
  end

  # @return [void]
  def clear_login_attempts
    Postal::RateLimiter.clear(login_ip_key)
    Postal::RateLimiter.clear(login_address_key)
  end

  # @return [String]
  def login_ip_key
    "web-login-ip:#{request.remote_ip}"
  end

  # @return [String]
  def login_address_key
    "web-login-address:#{request.remote_ip}:#{params[:email_address].to_s.downcase.first(255)}"
  end

  # Count this reset request and report whether either allowance has been spent.
  # It is checked before the address is looked up, so that the lookup cannot be
  # used as an oracle at volume.
  #
  # The address key deliberately omits the client address. A reset request sends
  # mail to the account's owner, so what a flood endangers is that mailbox; keying
  # on the client address as well would hand every client its own allowance
  # against the same mailbox, which is the abuse being prevented.
  #
  # @return [Boolean]
  def password_reset_rate_limited?
    Postal::RateLimiter.check(password_reset_ip_key,
                              limit: Postal::Config.protection.web_password_reset_limit,
                              period: Postal::Config.protection.web_password_reset_period).exceeded? ||
      Postal::RateLimiter.check(password_reset_address_key,
                                limit: Postal::Config.protection.web_password_reset_limit,
                                period: Postal::Config.protection.web_password_reset_period).exceeded?
  end

  # @return [String]
  def password_reset_ip_key
    "web-password-reset-ip:#{request.remote_ip}"
  end

  # @return [String]
  def password_reset_address_key
    "web-password-reset-address:#{params[:email_address].to_s.downcase.first(255)}"
  end

  # Count this redemption attempt against the client address before the token
  # is looked up, so the lookup cannot be used as an oracle at volume.
  #
  # @return [Boolean]
  def reset_redeem_rate_limited?
    Postal::RateLimiter.check_quota(:reset_redeem, request.remote_ip).exceeded?
  end

  def require_local_authentication
    return if Postal::Config.oidc.local_authentication_enabled?

    redirect_to login_path, alert: "Local authentication is not enabled"
  end

end
