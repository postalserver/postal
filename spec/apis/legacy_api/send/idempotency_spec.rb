# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Legacy Send API - Idempotency", type: :request do
  let(:server) { create(:server) }
  let(:credential) { create(:credential, server: server) }
  let(:domain) { create(:domain, owner: server) }

  describe "/api/v1/send/message with message_ids" do
    let(:default_params) do
      {
        to: ["test1@example.com", "test2@example.com"],
        from: "test@#{domain.name}",
        subject: "Test",
        plain_body: "Test body"
      }
    end

    context "when message_ids are provided" do
      let(:message_id_1) { "unique-id-1@example.com" }
      let(:message_id_2) { "unique-id-2@example.com" }
      let(:params) do
        default_params.merge(
          message_ids: {
            "test1@example.com" => message_id_1,
            "test2@example.com" => message_id_2
          }
        )
      end

      it "creates messages with the provided Message-IDs" do
        post "/api/v1/send/message",
             headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
             params: params.to_json

        parsed_body = JSON.parse(response.body)
        expect(parsed_body["status"]).to eq "success"

        message1 = server.message(parsed_body["data"]["messages"]["test1@example.com"]["id"])
        message2 = server.message(parsed_body["data"]["messages"]["test2@example.com"]["id"])

        expect(message1.message_id).to eq message_id_1
        expect(message2.message_id).to eq message_id_2
      end

      it "includes message_id in response" do
        post "/api/v1/send/message",
             headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
             params: params.to_json

        parsed_body = JSON.parse(response.body)
        expect(parsed_body["data"]["messages"]["test1@example.com"]["message_id"]).to eq message_id_1
        expect(parsed_body["data"]["messages"]["test2@example.com"]["message_id"]).to eq message_id_2
      end

      context "when Message-IDs have angle brackets" do
        let(:params) do
          default_params.merge(
            message_ids: {
              "test1@example.com" => "<#{message_id_1}>",
              "test2@example.com" => "<#{message_id_2}>"
            }
          )
        end

        it "strips angle brackets and stores without them" do
          post "/api/v1/send/message",
               headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
               params: params.to_json

          parsed_body = JSON.parse(response.body)
          message1 = server.message(parsed_body["data"]["messages"]["test1@example.com"]["id"])
          message2 = server.message(parsed_body["data"]["messages"]["test2@example.com"]["id"])

          expect(message1.message_id).to eq message_id_1
          expect(message2.message_id).to eq message_id_2
        end
      end

      context "when a duplicate Message-ID is sent" do
        before do
          # First request
          post "/api/v1/send/message",
               headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
               params: params.to_json
        end

        it "returns the existing message" do
          # Second request with same Message-IDs
          post "/api/v1/send/message",
               headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
               params: params.to_json

          parsed_body = JSON.parse(response.body)
          expect(parsed_body["status"]).to eq "success"
          expect(parsed_body["data"]["messages"]["test1@example.com"]["existing"]).to eq true
          expect(parsed_body["data"]["messages"]["test2@example.com"]["existing"]).to eq true
        end

        it "does not create a new message" do
          initial_count = server.message_db.messages.count

          # Second request
          post "/api/v1/send/message",
               headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
               params: params.to_json

          expect(server.message_db.messages.count).to eq initial_count
        end

        it "returns the same message ID and token" do
          first_response = JSON.parse(response.body)
          first_id_1 = first_response["data"]["messages"]["test1@example.com"]["id"]
          first_token_1 = first_response["data"]["messages"]["test1@example.com"]["token"]

          # Second request
          post "/api/v1/send/message",
               headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
               params: params.to_json

          second_response = JSON.parse(response.body)
          expect(second_response["data"]["messages"]["test1@example.com"]["id"]).to eq first_id_1
          expect(second_response["data"]["messages"]["test1@example.com"]["token"]).to eq first_token_1
        end
      end

      context "when partial duplicate (one recipient duplicate, one new)" do
        let(:params) do
          default_params.merge(
            message_ids: {
              "test1@example.com" => message_id_1,
              "test2@example.com" => message_id_2
            }
          )
        end

        before do
          # First request with only test1
          post "/api/v1/send/message",
               headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
               params: default_params.merge(
                 to: ["test1@example.com"],
                 message_ids: { "test1@example.com" => message_id_1 }
               ).to_json
        end

        it "returns existing for test1 and creates new for test2" do
          post "/api/v1/send/message",
               headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
               params: params.to_json

          parsed_body = JSON.parse(response.body)
          expect(parsed_body["data"]["messages"]["test1@example.com"]["existing"]).to eq true
          expect(parsed_body["data"]["messages"]["test2@example.com"]["existing"]).to be_nil
        end
      end
    end

    context "when message_ids are not provided" do
      it "generates unique Message-IDs for each recipient" do
        post "/api/v1/send/message",
             headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
             params: default_params.to_json

        parsed_body = JSON.parse(response.body)
        message1 = server.message(parsed_body["data"]["messages"]["test1@example.com"]["id"])
        message2 = server.message(parsed_body["data"]["messages"]["test2@example.com"]["id"])

        expect(message1.message_id).to be_a String
        expect(message2.message_id).to be_a String
        expect(message1.message_id).not_to eq message2.message_id
      end
    end

    context "when message_ids is provided but not a hash" do
      let(:params) { default_params.merge(message_ids: "not-a-hash") }

      it "ignores the parameter and generates Message-IDs" do
        post "/api/v1/send/message",
             headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
             params: params.to_json

        parsed_body = JSON.parse(response.body)
        expect(parsed_body["status"]).to eq "success"
        message1 = server.message(parsed_body["data"]["messages"]["test1@example.com"]["id"])
        expect(message1.message_id).to match(/\A[a-f0-9-]+@/)
      end
    end

    context "when message_ids have invalid format" do
      let(:params) do
        default_params.merge(
          message_ids: {
            "test1@example.com" => "invalid-no-domain",
            "test2@example.com" => "valid-id@example.com"
          }
        )
      end

      it "returns an error" do
        post "/api/v1/send/message",
             headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
             params: params.to_json

        parsed_body = JSON.parse(response.body)
        expect(parsed_body["status"]).to eq "error"
        expect(parsed_body["data"]["code"]).to eq "InvalidMessageID"
      end
    end

    context "when message_ids have missing local part" do
      let(:params) do
        default_params.merge(
          message_ids: {
            "test1@example.com" => "@example.com"
          }
        )
      end

      it "returns an error" do
        post "/api/v1/send/message",
             headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
             params: params.to_json

        parsed_body = JSON.parse(response.body)
        expect(parsed_body["status"]).to eq "error"
        expect(parsed_body["data"]["code"]).to eq "InvalidMessageID"
      end
    end

    context "when message_ids have spaces" do
      let(:params) do
        default_params.merge(
          message_ids: {
            "test1@example.com" => "id with spaces@example.com"
          }
        )
      end

      it "returns an error" do
        post "/api/v1/send/message",
             headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
             params: params.to_json

        parsed_body = JSON.parse(response.body)
        expect(parsed_body["status"]).to eq "error"
        expect(parsed_body["data"]["code"]).to eq "InvalidMessageID"
      end
    end
  end

  describe "/api/v1/send/raw with Message-ID in headers" do
    let(:raw_email) do
      "Message-ID: <raw-test-id@example.com>\r\n" \
      "From: test@#{domain.name}\r\n" \
      "To: recipient@example.com\r\n" \
      "Subject: Test\r\n" \
      "\r\n" \
      "Test body"
    end

    let(:default_params) do
      {
        rcpt_to: ["test1@example.com", "test2@example.com"],
        mail_from: "test@#{domain.name}",
        data: Base64.encode64(raw_email)
      }
    end

    context "when Message-ID is present in raw email" do
      it "extracts and uses the Message-ID" do
        post "/api/v1/send/raw",
             headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
             params: default_params.to_json

        parsed_body = JSON.parse(response.body)
        expect(parsed_body["status"]).to eq "success"

        message1 = server.message(parsed_body["data"]["messages"]["test1@example.com"]["id"])
        message2 = server.message(parsed_body["data"]["messages"]["test2@example.com"]["id"])

        expect(message1.message_id).to eq "raw-test-id@example.com"
        expect(message2.message_id).to eq "raw-test-id@example.com"
      end

      it "includes message_id in response" do
        post "/api/v1/send/raw",
             headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
             params: default_params.to_json

        parsed_body = JSON.parse(response.body)
        expect(parsed_body["data"]["messages"]["test1@example.com"]["message_id"]).to eq "raw-test-id@example.com"
        expect(parsed_body["data"]["messages"]["test2@example.com"]["message_id"]).to eq "raw-test-id@example.com"
      end

      context "when duplicate Message-ID is sent" do
        before do
          # First request
          post "/api/v1/send/raw",
               headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
               params: default_params.to_json
        end

        it "returns existing messages for all recipients" do
          # Second request with same Message-ID
          post "/api/v1/send/raw",
               headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
               params: default_params.to_json

          parsed_body = JSON.parse(response.body)
          expect(parsed_body["status"]).to eq "success"
          expect(parsed_body["data"]["messages"]["test1@example.com"]["existing"]).to eq true
          expect(parsed_body["data"]["messages"]["test2@example.com"]["existing"]).to eq true
        end

        it "does not create new messages" do
          initial_count = server.message_db.messages.count

          # Second request
          post "/api/v1/send/raw",
               headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
               params: default_params.to_json

          expect(server.message_db.messages.count).to eq initial_count
        end

        it "returns the same message IDs and tokens" do
          first_response = JSON.parse(response.body)
          first_id_1 = first_response["data"]["messages"]["test1@example.com"]["id"]
          first_token_1 = first_response["data"]["messages"]["test1@example.com"]["token"]

          # Second request
          post "/api/v1/send/raw",
               headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
               params: default_params.to_json

          second_response = JSON.parse(response.body)
          expect(second_response["data"]["messages"]["test1@example.com"]["id"]).to eq first_id_1
          expect(second_response["data"]["messages"]["test1@example.com"]["token"]).to eq first_token_1
        end
      end

      context "when partial duplicate (one recipient already exists)" do
        before do
          # First request with only test1
          post "/api/v1/send/raw",
               headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
               params: default_params.merge(rcpt_to: ["test1@example.com"]).to_json
        end

        it "returns existing for test1 and creates new for test2" do
          post "/api/v1/send/raw",
               headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
               params: default_params.to_json

          parsed_body = JSON.parse(response.body)
          expect(parsed_body["data"]["messages"]["test1@example.com"]["existing"]).to eq true
          expect(parsed_body["data"]["messages"]["test2@example.com"]["existing"]).to be_nil
        end

        it "only creates one new message" do
          initial_count = server.message_db.messages.count

          post "/api/v1/send/raw",
               headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
               params: default_params.to_json

          expect(server.message_db.messages.count).to eq initial_count + 1
        end
      end

      context "when Message-ID has angle brackets" do
        let(:raw_email_with_brackets) do
          "Message-ID: <<raw-bracketed-id@example.com>>\r\n" \
          "From: test@#{domain.name}\r\n" \
          "To: recipient@example.com\r\n" \
          "Subject: Test\r\n" \
          "\r\n" \
          "Test body"
        end

        let(:params_with_brackets) do
          default_params.merge(data: Base64.encode64(raw_email_with_brackets))
        end

        it "strips angle brackets before storage" do
          post "/api/v1/send/raw",
               headers: { "x-server-api-key" => credential.key, "content-type" => "application/json" },
               params: params_with_brackets.to_json

          parsed_body = JSON.parse(response.body)
          message = server.message(parsed_body["data"]["messages"]["test1@example.com"]["id"])

          expect(message.message_id).to eq "raw-bracketed-id@example.com"
        end
      end
    end
  end
end
