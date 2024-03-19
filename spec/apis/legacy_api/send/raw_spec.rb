# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Legacy Send API", type: :request do
  describe "/api/v1/send/raw" do
    context "when no authentication is provided" do
      it "returns an error" do
        post "/api/v1/send/raw"
        expect(response.status).to eq 200
        parsed_body = JSON.parse(response.body)
        expect(parsed_body["status"]).to eq "error"
        expect(parsed_body["data"]["code"]).to eq "AccessDenied"
      end
    end

    context "when the credential does not match anything" do
      it "returns an error" do
        post "/api/v1/send/raw", headers: { "x-server-api-key" => "invalid" }
        expect(response.status).to eq 200
        parsed_body = JSON.parse(response.body)
        expect(parsed_body["status"]).to eq "error"
        expect(parsed_body["data"]["code"]).to eq "InvalidServerAPIKey"
      end
    end

    context "when the credential belongs to a suspended server" do
      it "returns an error" do
        server = create(:server, :suspended)
        credential = create(:credential, server: server)
        post "/api/v1/send/raw", headers: { "x-server-api-key" => credential.key }
        expect(response.status).to eq 200
        parsed_body = JSON.parse(response.body)
        expect(parsed_body["status"]).to eq "error"
        expect(parsed_body["data"]["code"]).to eq "ServerSuspended"
      end
    end

    context "when the credential is valid" do
      let(:server) { create(:server) }
      let(:credential) { create(:credential, server: server) }
      let(:domain) { create(:domain, owner: server) }
      let(:data) do
        mail = Mail.new
        mail.to = "test1@example.com"
        mail.from = "test@#{domain.name}"
        mail.subject = "test"
        mail.text_part = Mail::Part.new
        mail.text_part.body = "plain text"
        mail.html_part = Mail::Part.new
        mail.html_part.content_type = "text/html; charset=UTF-8"
        mail.html_part.body = "<p>html</p>"
        mail
      end
      let(:default_params) do
        {
          mail_from: "test@#{domain.name}",
          rcpt_to: ["test1@example.com", "test2@example.com"],
          data: Base64.encode64(data.to_s),
          bounce: false
        }
      end
      let(:content_type) { "application/json" }
      let(:params) { default_params }

      before do
        post "/api/v1/send/raw",
             headers: { "x-server-api-key" => credential.key,
                        "content-type" => content_type },
             params: content_type == "application/json" ? params.to_json : params
      end

      context "when rcpt_to is not provided" do
        let(:params) { default_params.except(:rcpt_to) }

        it "returns an error" do
          parsed_body = JSON.parse(response.body)
          expect(parsed_body["status"]).to eq "parameter-error"
          expect(parsed_body["data"]["message"]).to match(/`rcpt_to` parameter is required but is missing/i)
        end
      end

      context "when mail_from is not provided" do
        let(:params) { default_params.except(:mail_from) }

        it "returns an error" do
          parsed_body = JSON.parse(response.body)
          expect(parsed_body["status"]).to eq "parameter-error"
          expect(parsed_body["data"]["message"]).to match(/`mail_from` parameter is required but is missing/i)
        end
      end

      context "when data is not provided" do
        let(:params) { default_params.except(:data) }

        it "returns an error" do
          parsed_body = JSON.parse(response.body)
          expect(parsed_body["status"]).to eq "parameter-error"
          expect(parsed_body["data"]["message"]).to match(/`data` parameter is required but is missing/i)
        end
      end

      context "when no recipients are provided" do
        let(:params) { default_params.merge(rcpt_to: []) }

        it "returns success but with no messages" do
          parsed_body = JSON.parse(response.body)
          expect(parsed_body["status"]).to eq "success"
          expect(parsed_body["data"]["messages"]).to eq({})
          expect(parsed_body["data"]["message_id"]).to be nil
        end
      end

      context "when a valid email is provided" do
        it "returns details of the messages created" do
          parsed_body = JSON.parse(response.body)
          expect(parsed_body["data"]["message_id"]).to be_a String
          expect(parsed_body["data"]["messages"]).to be_a Hash
          expect(parsed_body["data"]["messages"]).to match({
            "test1@example.com" => { "id" => kind_of(Integer), "token" => /\A[a-zA-Z0-9]{16}\z/ },
            "test2@example.com" => { "id" => kind_of(Integer), "token" => /\A[a-zA-Z0-9]{16}\z/ }
          })
        end

        it "creates appropriate message objects" do
          parsed_body = JSON.parse(response.body)
          ["test1@example.com", "test2@example.com"].each do |rcpt_to|
            message_id = parsed_body["data"]["messages"][rcpt_to]["id"]
            message = server.message(message_id)
            expect(message).to have_attributes(
              server: server,
              rcpt_to: rcpt_to,
              mail_from: "test@#{domain.name}",
              subject: "test",
              message_id: kind_of(String),
              timestamp: kind_of(Time),
              domain_id: domain.id,
              credential_id: credential.id,
              bounce: false,
              headers: hash_including("to" => ["test1@example.com"]),
              plain_body: "plain text",
              html_body: "<p>html</p>",
              attachments: [],
              received_with_ssl: true,
              scope: "outgoing",
              raw_message: data.to_s
            )
          end
        end

        context "when params are provided as a param" do
          let(:content_type) { nil }
          let(:params) { { params: default_params.to_json } }

          it "returns details of the messages created" do
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["data"]["message_id"]).to be_a String
            expect(parsed_body["data"]["messages"]).to be_a Hash
            expect(parsed_body["data"]["messages"]).to match({
              "test1@example.com" => { "id" => kind_of(Integer), "token" => /\A[a-zA-Z0-9]{16}\z/ },
              "test2@example.com" => { "id" => kind_of(Integer), "token" => /\A[a-zA-Z0-9]{16}\z/ }
            })
          end
        end
      end
    end
  end
end
