# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Legacy Messages API", type: :request do
  describe "/api/v1/messages/message" do
    context "when no authentication is provided" do
      it "returns an error" do
        post "/api/v1/messages/message"
        expect(response.status).to eq 200
        parsed_body = JSON.parse(response.body)
        expect(parsed_body["status"]).to eq "error"
        expect(parsed_body["data"]["code"]).to eq "AccessDenied"
      end
    end

    context "when the credential does not match anything" do
      it "returns an error" do
        post "/api/v1/messages/message", headers: { "x-server-api-key" => "invalid" }
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
        post "/api/v1/messages/message", headers: { "x-server-api-key" => credential.key }
        expect(response.status).to eq 200
        parsed_body = JSON.parse(response.body)
        expect(parsed_body["status"]).to eq "error"
        expect(parsed_body["data"]["code"]).to eq "ServerSuspended"
      end
    end

    context "when the credential is valid" do
      let(:server) { create(:server) }
      let(:credential) { create(:credential, server: server) }

      context "when no message ID is provided" do
        it "returns an error" do
          post "/api/v1/messages/message", headers: { "x-server-api-key" => credential.key }
          expect(response.status).to eq 200
          parsed_body = JSON.parse(response.body)
          expect(parsed_body["status"]).to eq "parameter-error"
          expect(parsed_body["data"]["message"]).to match(/`id` parameter is required but is missing/)
        end
      end

      context "when the message ID does not exist" do
        it "returns an error" do
          post "/api/v1/messages/message",
               headers: { "x-server-api-key" => credential.key,
                          "content-type" => "application/json" },
               params: { id: 123 }.to_json
          expect(response.status).to eq 200
          parsed_body = JSON.parse(response.body)
          expect(parsed_body["status"]).to eq "error"
          expect(parsed_body["data"]["code"]).to eq "MessageNotFound"
        end
      end

      context "when the message ID exists" do
        let(:server) { create(:server) }
        let(:credential) { create(:credential, server: server) }
        let(:message) { MessageFactory.outgoing(server) }
        let(:expansions) { [] }

        before do
          post "/api/v1/messages/message",
               headers: { "x-server-api-key" => credential.key,
                          "content-type" => "application/json" },
               params: { id: message.id, _expansions: expansions }.to_json
        end

        context "when no expansions are requested" do
          it "returns details about the message" do
            expect(response.status).to eq 200
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "success"
            expect(parsed_body["data"]).to match({
              "id" => message.id,
              "token" => message.token
            })
          end
        end

        context "when all expansions are requested" do
          let(:expansions) { true }

          it "returns details about the message" do
            expect(response.status).to eq 200
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "success"
            expect(parsed_body["data"]).to match({
              "id" => message.id,
              "token" => message.token,
              "status" => { "held" => false,
                            "hold_expiry" => nil,
                            "last_delivery_attempt" => nil,
                            "status" => "Pending" },
              "details" => { "bounce" => false,
                             "bounce_for_id" => 0,
                             "direction" => "outgoing",
                             "mail_from" => "test@example.com",
                             "message_id" => message.message_id,
                             "rcpt_to" => "john@example.com",
                             "received_with_ssl" => nil,
                             "size" => kind_of(String),
                             "subject" => "An example message",
                             "tag" => nil,
                             "timestamp" => kind_of(Float) },
              "inspection" => { "inspected" => false,
                                "spam" => false,
                                "spam_score" => 0.0,
                                "threat" => false,
                                "threat_details" => nil },
              "plain_body" => message.plain_body,
              "html_body" => message.html_body,
              "attachments" => [],
              "headers" => message.headers,
              "raw_message" => Base64.encode64(message.raw_message),
              "activity_entries" => {
                "loads" => [],
                "clicks" => []
              }
            })
          end
        end

        context "when the status expansion is requested" do
          let(:expansions) { ["status"] }

          it "returns details about the message" do
            expect(response.status).to eq 200
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "success"
            expect(parsed_body["data"]).to match({
              "id" => message.id,
              "token" => message.token,
              "status" => { "held" => false,
                            "hold_expiry" => nil,
                            "last_delivery_attempt" => nil,
                            "status" => "Pending" }
            })
          end
        end

        context "when the details expansion is requested" do
          let(:expansions) { ["details"] }

          it "returns details about the message" do
            expect(response.status).to eq 200
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "success"
            expect(parsed_body["data"]).to match({
              "id" => message.id,
              "token" => message.token,
              "details" => { "bounce" => false,
                             "bounce_for_id" => 0,
                             "direction" => "outgoing",
                             "mail_from" => "test@example.com",
                             "message_id" => message.message_id,
                             "rcpt_to" => "john@example.com",
                             "received_with_ssl" => nil,
                             "size" => kind_of(String),
                             "subject" => "An example message",
                             "tag" => nil,
                             "timestamp" => kind_of(Float) }
            })
          end
        end

        context "when the details expansion is requested" do
          let(:expansions) { ["inspection"] }

          it "returns details about the message" do
            expect(response.status).to eq 200
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "success"
            expect(parsed_body["data"]).to match({
              "id" => message.id,
              "token" => message.token,
              "inspection" => { "inspected" => false,
                                "spam" => false,
                                "spam_score" => 0.0,
                                "threat" => false,
                                "threat_details" => nil }
            })
          end
        end

        context "when the body expansions are requested" do
          let(:expansions) { %w[plain_body html_body] }

          it "returns details about the message" do
            expect(response.status).to eq 200
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "success"
            expect(parsed_body["data"]).to match({
              "id" => message.id,
              "token" => message.token,
              "plain_body" => message.plain_body,
              "html_body" => message.html_body
            })
          end
        end

        context "when the attachments expansions is requested" do
          let(:message) do
            MessageFactory.outgoing(server) do |_, mail|
              mail.attachments["example.txt"] = "hello world!"
            end
          end
          let(:expansions) { ["attachments"] }

          it "returns details about the message" do
            expect(response.status).to eq 200
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "success"
            expect(parsed_body["data"]).to match({
              "id" => message.id,
              "token" => message.token,
              "attachments" => [
                {
                  "content_type" => "text/plain",
                  "data" => Base64.encode64("hello world!"),
                  "filename" => "example.txt",
                  "hash" => Digest::SHA1.hexdigest("hello world!"),
                  "size" => 12
                },
              ]
            })
          end
        end

        context "when the headers expansions is requested" do
          let(:expansions) { ["headers"] }

          it "returns details about the message" do
            expect(response.status).to eq 200
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "success"
            expect(parsed_body["data"]).to match({
              "id" => message.id,
              "token" => message.token,
              "headers" => message.headers
            })
          end
        end

        context "when the raw_message expansions is requested" do
          let(:expansions) { ["raw_message"] }

          it "returns details about the message" do
            expect(response.status).to eq 200
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "success"
            expect(parsed_body["data"]).to match({
              "id" => message.id,
              "token" => message.token,
              "raw_message" => Base64.encode64(message.raw_message)
            })
          end
        end

        context "when the activity_entries expansions is requested" do
          let(:message) do
            MessageFactory.outgoing(server) do |msg|
              msg.create_load(double("request", ip: "1.2.3.4", user_agent: "user agent"))
              link = msg.create_link("https://example.com")
              link_id = msg.database.select(:links, where: { token: link }).first["id"]
              msg.database.insert(:clicks, {
                message_id: msg.id,
                link_id: link_id,
                ip_address: "1.2.3.4",
                user_agent: "user agent",
                timestamp: Time.now.to_f
              })
            end
          end
          let(:expansions) { ["activity_entries"] }

          it "returns details about the message" do
            expect(response.status).to eq 200
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "success"
            expect(parsed_body["data"]).to match({
              "id" => message.id,
              "token" => message.token,
              "activity_entries" => {
                "loads" => [{
                  "ip_address" => "1.2.3.4",
                  "user_agent" => "user agent",
                  "timestamp" => match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z\z/)
                }],
                "clicks" => [{
                  "url" => "https://example.com",
                  "ip_address" => "1.2.3.4",
                  "user_agent" => "user agent",
                  "timestamp" => match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z\z/)
                }]
              }
            })
          end
        end
      end
    end
  end
end
