# frozen_string_literal: true

require "rails_helper"

# These examples exist to exercise the view layer end to end - HAML, the asset
# pipeline, the layout, form helpers and the session middleware. The rest of the
# request specs only assert on redirects, so without these nothing in the suite
# would notice if a Rails upgrade broke rendering.
RSpec.describe "rendering", type: :request do
  before do
    host! Postal::Config.postal.web_hostname
  end

  describe "the login page" do
    it "renders" do
      get "/login"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq "text/html"
      expect(response.body).to include "<form"
      expect(response.body).to include "password"
    end

    it "renders the layout including compiled assets" do
      get "/login"

      expect(response.body).to include "<html"
      expect(response.body).to match(/<link[^>]+stylesheets?/i).or match(/<link[^>]+\.css/i)
      expect(response.body).to match(/<script[^>]+\.js/i)
    end
  end

  describe "when not authenticated" do
    it "redirects to the login page" do
      get "/"

      expect(response).to redirect_to("/login?return_to=%2F")
    end
  end

  describe "when authenticated" do
    let(:user) { create(:user) }

    before do
      post "/login", params: { email_address: user.email_address, password: "passw0rd" }
    end

    it "renders the organizations index" do
      get "/"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include "<html"
    end

    it "renders the user settings page" do
      get "/settings"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include user.email_address
    end

    # `f.error_messages` and `error_messages_for` used to come from the
    # dynamic_form gem. The app provides them itself now (see
    # ErrorMessagesHelper and config/initializers/form_builder_extensions.rb),
    # so the rendered output is our responsibility to keep working.
    describe "a form which fails validation" do
      before do
        patch "/settings", params: {
          password: "passw0rd",
          user: { first_name: "", last_name: "Smith", email_address: user.email_address }
        }
      end

      it "re-renders the form" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the validation errors in the errorExplanation container" do
        expect(response.body).to include %(<div id="errorExplanation" class="errorExplanation">)
        expect(response.body).to include "<li>First name can&#39;t be blank</li>"
      end
    end

    it "does not render an error container on a form which has no errors" do
      get "/settings"

      expect(response.body).to_not include "errorExplanation"
    end
  end
end
