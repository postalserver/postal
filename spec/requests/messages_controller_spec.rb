# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MessagesController", type: :request do
  let(:user) { create(:user, admin: true) }
  let(:organization) { create(:organization, owner: user) }
  let(:server) { create(:server, organization: organization) }

  before do
    post "/login", params: { email_address: user.email_address, password: "passw0rd" }
  end

  describe "GET /org/:org/servers/:server/messages/:id/html_raw" do
    let(:xss_payload) { %(<script>alert("XSS")</script>) }
    let(:message) do
      payload = xss_payload
      MessageFactory.incoming(server) do |_msg, mail|
        mail.html_part = Mail::Part.new do
          content_type "text/html; charset=UTF-8"
          body %(<html><body><p>hello</p>#{payload}</body></html>)
        end
      end
    end

    before do
      get "/org/#{organization.permalink}/servers/#{server.permalink}/messages/#{message.id}/html_raw"
    end

    it "returns the stored email HTML" do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("hello")
    end

    it "serves a restrictive Content-Security-Policy that blocks scripts" do
      csp = response.headers["Content-Security-Policy"]
      expect(csp).to include("script-src 'none'")
      expect(csp).to include("default-src 'none'")
      expect(csp).to include("form-action 'none'")
      expect(csp).to include("base-uri 'none'")
    end

    it "sets X-Content-Type-Options and Referrer-Policy on the response" do
      expect(response.headers["X-Content-Type-Options"]).to eq "nosniff"
      expect(response.headers["Referrer-Policy"]).to eq "no-referrer"
    end
  end

  describe "messages/html view template" do
    # We assert against the template source rather than rendering it in a
    # request spec because the full application layout depends on the asset
    # pipeline which is not configured in this test environment.
    it "embeds the html_raw view inside a sandboxed iframe" do
      template = Rails.root.join("app/views/messages/html.html.haml").read
      expect(template).to match(/%iframe\{[^}]*:sandbox\s*=>/)
    end
  end
end
