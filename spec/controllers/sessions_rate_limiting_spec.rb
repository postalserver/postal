# frozen_string_literal: true

require "rails_helper"

RSpec.describe SessionsController, type: :controller do
  before do
    allow(Postal::Config.protection).to receive(:web_login_failures_limit).and_return(2)
    allow(Postal::Config.protection).to receive(:web_login_failures_period).and_return(300)
  end

  def attempt_login
    post :create, params: { email_address: "nobody@example.com", password: "wrong" }
  end

  it "stops calling the authenticator once the allowance is spent" do
    2.times { attempt_login }

    expect(User).not_to receive(:authenticate)

    attempt_login
  end

  it "forgets both counts when a login succeeds" do
    user = create(:user)

    expect(Postal::RateLimiter).to receive(:clear)
      .with(a_string_starting_with("web-login-ip:")).and_call_original
    expect(Postal::RateLimiter).to receive(:clear)
      .with(a_string_starting_with("web-login-address:")).and_call_original

    post :create, params: { email_address: user.email_address, password: "passw0rd" }
  end

  describe "password reset requests" do
    before do
      allow(Postal::Config.protection).to receive(:web_password_reset_limit).and_return(2)
      allow(Postal::Config.protection).to receive(:web_password_reset_period).and_return(900)
    end

    def request_reset
      post :begin_password_reset, params: { email_address: "nobody@example.com" }
    end

    it "does not say whether the address has an account" do
      request_reset
      unmatched = flash[:notice]

      post :begin_password_reset, params: { email_address: create(:user).email_address }

      expect(flash[:notice]).to eq unmatched
      expect(flash[:alert]).to be_nil
    end

    it "refuses further reset requests once the allowance is spent" do
      2.times { request_reset }
      request_reset

      expect(response).to be_redirect
      expect(flash[:alert]).to include("Too many password reset requests")
    end

    it "counts reset requests against the address being reset rather than only the client" do
      allow(Postal::RateLimiter).to receive(:check).and_call_original

      request_reset

      expect(Postal::RateLimiter).to have_received(:check)
        .with("web-password-reset-address:nobody@example.com", any_args)
    end

    it "counts reset requests against the client address" do
      allow(Postal::RateLimiter).to receive(:check).and_call_original

      request_reset

      expect(Postal::RateLimiter).to have_received(:check)
        .with(a_string_starting_with("web-password-reset-ip:"), any_args)
    end
  end
end
