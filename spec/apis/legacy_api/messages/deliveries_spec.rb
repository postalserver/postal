# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Legacy Messages API", type: :request do
  describe "/api/v1/messages/deliveries" do
    context "when no authentication is provided" do
      it "returns an error" do
        post "/api/v1/messages/deliveries"
        expect(response.status).to eq 200
        parsed_body = JSON.parse(response.body)
        expect(parsed_body["status"]).to eq "error"
        expect(parsed_body["data"]["code"]).to eq "AccessDenied"
      end
    end

    context "when the credential does not match anything" do
      it "returns an error" do
        post "/api/v1/messages/deliveries", headers: { "x-server-api-key" => "invalid" }
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
        post "/api/v1/messages/deliveries", headers: { "x-server-api-key" => credential.key }
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
          post "/api/v1/messages/deliveries", headers: { "x-server-api-key" => credential.key }
          expect(response.status).to eq 200
          parsed_body = JSON.parse(response.body)
          expect(parsed_body["status"]).to eq "parameter-error"
          expect(parsed_body["data"]["message"]).to match(/`id` parameter is required but is missing/)
        end
      end

      context "when the message ID does not exist" do
        it "returns an error" do
          post "/api/v1/messages/deliveries",
               headers: { "x-server-api-key" => credential.key,
                          "content-type" => "application/json" },
               params: { id: 123 }.to_json
          expect(response.status).to eq 200
          parsed_body = JSON.parse(response.body)
          expect(parsed_body["status"]).to eq "error"
          expect(parsed_body["data"]["code"]).to eq "MessageNotFound"
          expect(parsed_body["data"]["id"]).to eq 123
        end
      end

      context "when the message ID exists" do
        let(:server) { create(:server) }
        let(:credential) { create(:credential, server: server) }
        let(:message) { MessageFactory.outgoing(server) }

        before do
          message.create_delivery("SoftFail", details: "no server found",
                                              output: "404",
                                              sent_with_ssl: true,
                                              log_id: "1234",
                                              time: 1.2)
          message.create_delivery("Sent", details: "sent successfully",
                                          output: "200",
                                          sent_with_ssl: false,
                                          log_id: "5678",
                                          time: 2.2)
        end

        before do
          post "/api/v1/messages/deliveries",
               headers: { "x-server-api-key" => credential.key,
                          "content-type" => "application/json" },
               params: { id: message.id }.to_json
        end

        it "returns an array of deliveries" do
          expect(response.status).to eq 200
          parsed_body = JSON.parse(response.body)
          expect(parsed_body["status"]).to eq "success"
          expect(parsed_body["data"]).to match([
                                                 { "id" => kind_of(Integer),
                                                   "status" => "SoftFail",
                                                   "details" => "no server found",
                                                   "output" => "404",
                                                   "sent_with_ssl" => true,
                                                   "log_id" => "1234",
                                                   "time" => 1.2,
                                                   "timestamp" => kind_of(Float) },
                                                 { "id" => kind_of(Integer),
                                                   "status" => "Sent",
                                                   "details" => "sent successfully",
                                                   "output" => "200",
                                                   "sent_with_ssl" => false,
                                                   "log_id" => "5678",
                                                   "time" => 2.2,
                                                   "timestamp" => kind_of(Float) },
                                               ])
        end
      end
    end
  end
end
