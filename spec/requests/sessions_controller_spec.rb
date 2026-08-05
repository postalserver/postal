# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SessionsController", type: :request do
  let(:user) { create(:user) }

  describe "POST /login with return_to" do
    def login_with(return_to:)
      post "/login", params: {
        email_address: user.email_address,
        password: "passw0rd",
        return_to: return_to
      }
    end

    shared_examples "rejects unsafe return_to" do
      it "does not redirect to the attacker-controlled location" do
        login_with(return_to: unsafe_path)

        expect(response).to have_http_status(:found)
        # Whatever the fallback is, it must be same-origin: a Location that
        # either omits a host or points at our own host. A browser must not
        # end up at attacker.example.
        location = response.location
        expect(location).not_to include("attacker.example")
        # Reject protocol-relative and absolute redirects entirely.
        expect(location).not_to match(%r{\A//})
        expect(location).not_to match(%r{\Ahttps?://attacker})
      end
    end

    context "with a protocol-relative URL (//host)" do
      let(:unsafe_path) { "//attacker.example/phish" }
      include_examples "rejects unsafe return_to"
    end

    context "with a backslash-prefixed URL (/\\host)" do
      let(:unsafe_path) { "/\\attacker.example/phish" }
      include_examples "rejects unsafe return_to"
    end

    context "with an absolute http(s) URL" do
      let(:unsafe_path) { "https://attacker.example/phish" }
      include_examples "rejects unsafe return_to"
    end

    context "with a javascript: URL" do
      let(:unsafe_path) { "javascript:alert(1)" }
      include_examples "rejects unsafe return_to"
    end

    context "with a safe relative path" do
      it "honours the return_to" do
        login_with(return_to: "/org/acme/settings")
        expect(response).to redirect_to("/org/acme/settings")
      end
    end

    context "with no return_to" do
      it "redirects to the default root" do
        post "/login", params: {
          email_address: user.email_address,
          password: "passw0rd"
        }
        expect(response).to have_http_status(:found)
        expect(response.location).not_to match(%r{\A//})
      end
    end
  end
end
