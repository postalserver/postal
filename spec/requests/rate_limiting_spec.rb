# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rate limiting", type: :request do
  describe "the legacy API" do
    before do
      allow(Postal::Config.protection).to receive(:api_auth_failures_limit).and_return(2)
      allow(Postal::Config.protection).to receive(:api_auth_failures_period).and_return(300)
    end

    def post_message_with_key(key)
      post "/api/v1/send/message",
           params: { to: "test@example.com" },
           headers: { "X-Server-API-Key" => key }
    end

    it "refuses a client which has spent its allowance and says when to retry" do
      2.times do
        post_message_with_key("not-a-real-key")
        expect(response.parsed_body["data"]["code"]).to eq "InvalidServerAPIKey"
      end

      post_message_with_key("not-a-real-key")

      expect(response.parsed_body["data"]["code"]).to eq "RateLimited"
      expect(response.headers["Retry-After"]).to eq "300"
    end

    it "does not spend the allowance of a client which authenticates successfully" do
      credential = create(:credential, type: "API", server: create(:server))

      4.times do
        post_message_with_key(credential.key)
        expect(response.parsed_body["data"]["code"]).not_to eq "RateLimited"
      end
    end

    it "asks a client which sends no key to authenticate" do
      post "/api/v1/send/message", params: { to: "test@example.com" }

      expect(response.parsed_body["data"]["code"]).to eq "AccessDenied"
    end

    it "does not echo the rejected key back, so a wrong key cannot be harvested from logs" do
      post_message_with_key("wrong")

      expect(response.parsed_body["data"]["code"]).to eq "InvalidServerAPIKey"
      expect(response.parsed_body["data"]).not_to have_key("token")
    end

    it "refuses a suspended server even when the key is valid" do
      credential = create(:credential, type: "API", server: create(:server, :suspended))

      post_message_with_key(credential.key)

      expect(response.parsed_body["data"]["code"]).to eq "ServerSuspended"
    end

    it "does not limit anything while protection is switched off" do
      allow(Postal::Config.protection).to receive(:enabled).and_return(false)

      5.times { post_message_with_key("wrong") }

      expect(response.parsed_body["data"]["code"]).to eq "InvalidServerAPIKey"
    end

    describe "per-credential send quotas" do
      before do
        allow(Postal::Config.protection).to receive(:api_send_limit).and_return(2)
        allow(Postal::Config.protection).to receive(:api_send_period).and_return(300)
      end

      it "refuses a credential which has spent its allowance and says when to retry" do
        credential = create(:credential, type: "API", server: create(:server))

        2.times do
          post_message_with_key(credential.key)
          expect(response.parsed_body["data"]["code"]).not_to eq "RateLimited"
        end

        post_message_with_key(credential.key)

        expect(response.parsed_body["data"]["code"]).to eq "RateLimited"
        expect(response.headers["Retry-After"]).to eq "300"
      end

      it "counts each credential separately" do
        first = create(:credential, type: "API", server: create(:server))
        second = create(:credential, type: "API", server: first.server)

        2.times { post_message_with_key(first.key) }
        post_message_with_key(first.key)
        expect(response.parsed_body["data"]["code"]).to eq "RateLimited"

        post_message_with_key(second.key)
        expect(response.parsed_body["data"]["code"]).not_to eq "RateLimited"
      end

      it "does nothing while the quota is disabled" do
        allow(Postal::Config.protection).to receive(:api_send_limit).and_return(0)
        credential = create(:credential, type: "API", server: create(:server))

        4.times do
          post_message_with_key(credential.key)
          expect(response.parsed_body["data"]["code"]).not_to eq "RateLimited"
        end
      end
    end
  end

  describe "web login" do
    let(:user) { create(:user) }

    before do
      allow(Postal::Config.protection).to receive(:web_login_failures_limit).and_return(2)
      allow(Postal::Config.protection).to receive(:web_login_failures_period).and_return(300)
    end

    def attempt_login(password)
      post "/login", params: { email_address: user.email_address, password: password }
    end

    it "does not spend the allowance of a user who logs in successfully" do
      4.times do
        attempt_login("passw0rd")
        expect(flash[:alert]).to be_nil
      end
    end
  end
end
