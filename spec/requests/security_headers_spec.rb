# frozen_string_literal: true

require "rails_helper"

# The security headers come from the secure_headers gem plus Rails' own
# defaults, and both have changed them across major versions. Nothing else in
# the suite looks at response headers, so pin them here.
RSpec.describe "security headers", type: :request do
  before do
    host! Postal::Config.postal.web_hostname
    get "/login"
  end

  it "responds successfully" do
    expect(response).to have_http_status(:ok)
  end

  it "sets X-Frame-Options to sameorigin" do
    expect(response.headers["x-frame-options"]).to eq "sameorigin"
  end

  it "sets X-Content-Type-Options to nosniff" do
    expect(response.headers["x-content-type-options"]).to eq "nosniff"
  end

  it "disables the legacy XSS auditor rather than enabling it" do
    # secure_headers 7 changed this from "1; mode=block". `0` is correct: the
    # legacy auditor is deprecated and blocking mode was itself exploitable.
    expect(response.headers["x-xss-protection"]).to eq "0"
  end

  it "sets X-Permitted-Cross-Domain-Policies to none" do
    expect(response.headers["x-permitted-cross-domain-policies"]).to eq "none"
  end

  describe "the content security policy" do
    let(:csp) { response.headers["content-security-policy"] }

    it "is present" do
      expect(csp).to be_present
    end

    it "restricts script-src to self" do
      expect(csp).to include "script-src 'self'"
    end

    it "restricts connect-src to self" do
      expect(csp).to include "connect-src 'self'"
    end

    it "forbids object-src" do
      expect(csp).to include "object-src 'none'"
    end
  end

  describe "cookies" do
    # Rack 3 returns set-cookie as a String for one cookie and an Array for
    # several, so normalise before looking for a particular cookie.
    def cookie_named(name)
      Array(response.headers["set-cookie"]).flat_map { |v| v.split("\n") }.find { |c| c.start_with?("#{name}=") }
    end

    it "marks the browser id cookie httponly and samesite lax" do
      expect(cookie_named("browser_id")).to include "httponly"
      expect(cookie_named("browser_id")).to include "samesite=lax"
    end

    context "once logged in" do
      let(:user) { create(:user) }

      before do
        post "/login", params: { email_address: user.email_address, password: "passw0rd" }
      end

      it "marks the authie session cookie httponly and samesite lax" do
        expect(cookie_named("user_session")).to include "httponly"
        expect(cookie_named("user_session")).to include "samesite=lax"
      end

      it "marks the rails session cookie httponly and samesite lax" do
        expect(cookie_named("_postal_session")).to include "httponly"
        expect(cookie_named("_postal_session")).to include "samesite=lax"
      end
    end
  end
end
