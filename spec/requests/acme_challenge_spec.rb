# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ACME HTTP-01 challenge" do
  before do
    host! "mta-sts.example.com"
  end

  it "serves a stored challenge response as plain text" do
    ACMEChallenge.store!("a-token", "a-token.thumbprint")
    get "/.well-known/acme-challenge/a-token"
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq "text/plain"
    expect(response.body).to eq "a-token.thumbprint"
  end

  it "does not redirect" do
    ACMEChallenge.store!("a-token", "content")
    get "/.well-known/acme-challenge/a-token"
    expect(response).to_not be_redirect
  end

  it "returns not found for a token which was never stored" do
    get "/.well-known/acme-challenge/unknown"
    expect(response).to have_http_status(:not_found)
  end

  it "returns not found for an expired token" do
    ACMEChallenge.store!("a-token", "content", expires_at: 1.minute.ago)
    get "/.well-known/acme-challenge/a-token"
    expect(response).to have_http_status(:not_found)
  end
end
