# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Legacy Send API", type: :request do
  describe "/api/v1/send/message" do
    context "when no authentication is provided" do
      it "returns an error" do
        post "/api/v1/send/message"
        expect(response.status).to eq 200
        parsed_body = JSON.parse(response.body)
        expect(parsed_body["status"]).to eq "error"
        expect(parsed_body["data"]["code"]).to eq "AccessDenied"
      end
    end

    context "when the credential does not match anything" do
      it "returns an error" do
        post "/api/v1/send/message", headers: { "x-server-api-key" => "invalid" }
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
        post "/api/v1/send/message", headers: { "x-server-api-key" => credential.key }
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

      context "when parameters are provided in a JSON body" do
        let(:default_params) do
          {
            to: ["test@example.com"],
            cc: ["cc@example.com"],
            bcc: ["bcc@example.com"],
            from: "test@#{domain.name}",
            sender: "sender@#{domain.name}",
            tag: "test-tag",
            reply_to: "reply@example.com",
            plain_body: "plain text",
            html_body: "<p>html</p>",
            attachments: [{ name: "test1.txt", content_type: "text/plain", data: Base64.encode64("hello world 1") },
                          { name: "test2.txt", content_type: "text/plain", data: Base64.encode64("hello world 2") },],
            headers: { "x-test-header-1" => "111", "x-test-header-2" => "222" },
            bounce: false,
            subject: "Test"
          }
        end
        let(:params) { default_params }

        before do
          post "/api/v1/send/message",
               headers: { "x-server-api-key" => credential.key,
                          "content-type" => "application/json" },
               params: params.to_json
        end

        context "when no recipients are provided" do
          let(:params) { default_params.merge(to: [], cc: [], bcc: []) }

          it "returns an error" do
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "error"
            expect(parsed_body["data"]["code"]).to eq "NoRecipients"
            expect(parsed_body["data"]["message"]).to match(/there are no recipients defined to receive this message/i)
          end
        end

        context "when no content is provided" do
          let(:params) { default_params.merge(html_body: nil, plain_body: nil) }

          it "returns an error" do
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "error"
            expect(parsed_body["data"]["code"]).to eq "NoContent"
            expect(parsed_body["data"]["message"]).to match(/there is no content defined for this e-mail/i)
          end
        end

        context "when the number of 'To' recipients exceeds the maximum" do
          let(:params) { default_params.merge(to: ["a@a.com"] * 51) }

          it "returns an error" do
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "error"
            expect(parsed_body["data"]["code"]).to eq "TooManyToAddresses"
            expect(parsed_body["data"]["message"]).to match(/the maximum number of To addresses has been reached/i)
          end
        end

        context "when the number of 'CC' recipients exceeds the maximum" do
          let(:params) { default_params.merge(cc: ["a@a.com"] * 51) }

          it "returns an error" do
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "error"
            expect(parsed_body["data"]["code"]).to eq "TooManyCCAddresses"
            expect(parsed_body["data"]["message"]).to match(/the maximum number of CC addresses has been reached/i)
          end
        end

        context "when the number of 'BCC' recipients exceeds the maximum" do
          let(:params) { default_params.merge(bcc: ["a@a.com"] * 51) }

          it "returns an error" do
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "error"
            expect(parsed_body["data"]["code"]).to eq "TooManyBCCAddresses"
            expect(parsed_body["data"]["message"]).to match(/the maximum number of BCC addresses has been reached/i)
          end
        end

        context "when the 'From' address is missing" do
          let(:params) { default_params.merge(from: nil) }

          it "returns an error" do
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "error"
            expect(parsed_body["data"]["code"]).to eq "FromAddressMissing"
            expect(parsed_body["data"]["message"]).to match(/the from address is missing and is required/i)
          end
        end

        context "when the 'From' address is not authorised" do
          let(:params) { default_params.merge(from: "test@another.com") }

          it "returns an error" do
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "error"
            expect(parsed_body["data"]["code"]).to eq "UnauthenticatedFromAddress"
            expect(parsed_body["data"]["message"]).to match(/the from address is not authorised to send mail from this server/i)
          end
        end

        context "when an attachment is missing a name" do
          let(:params) { default_params.merge(attachments: [{ name: nil, content_type: "text/plain", data: Base64.encode64("hello world 1") }]) }

          it "returns an error" do
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "error"
            expect(parsed_body["data"]["code"]).to eq "AttachmentMissingName"
            expect(parsed_body["data"]["message"]).to match(/an attachment is missing a name/i)
          end
        end

        context "when an attachment is missing data" do
          let(:params) { default_params.merge(attachments: [{ name: "test1.txt", content_type: "text/plain", data: nil }]) }

          it "returns an error" do
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "error"
            expect(parsed_body["data"]["code"]).to eq "AttachmentMissingData"
            expect(parsed_body["data"]["message"]).to match(/an attachment is missing data/i)
          end
        end

        context "when an attachment entry is not a hash" do
          let(:params) { default_params.merge(attachments: [123, "string"]) }

          it "continues as if it wasn't there" do
            parsed_body = JSON.parse(response.body)
            ["test@example.com", "cc@example.com", "bcc@example.com"].each do |rcpt_to|
              message_id = parsed_body["data"]["messages"][rcpt_to]["id"]
              message = server.message(message_id)
              expect(message.attachments).to be_empty
            end
          end
        end

        context "when given a complete email to send" do
          it "returns details of the messages created" do
            parsed_body = JSON.parse(response.body)
            expect(parsed_body["status"]).to eq "success"
            expect(parsed_body["data"]["messages"]).to match({
              "test@example.com" => { "id" => kind_of(Integer), "token" => /\A[a-zA-Z0-9]{16}\z/ },
              "cc@example.com" => { "id" => kind_of(Integer), "token" => /\A[a-zA-Z0-9]{16}\z/ },
              "bcc@example.com" => { "id" => kind_of(Integer), "token" => /\A[a-zA-Z0-9]{16}\z/ }
            })
          end

          it "adds an appropriate received header" do
            parsed_body = JSON.parse(response.body)
            message_id = parsed_body["data"]["messages"]["test@example.com"]["id"]
            message = server.message(message_id)
            expect(message.headers["received"].first).to match(/\Afrom api/)
          end

          it "creates appropriate message objects" do
            parsed_body = JSON.parse(response.body)
            ["test@example.com", "cc@example.com", "bcc@example.com"].each do |rcpt_to|
              message_id = parsed_body["data"]["messages"][rcpt_to]["id"]
              message = server.message(message_id)
              expect(message).to have_attributes(
                server: server,
                rcpt_to: rcpt_to,
                mail_from: params[:from],
                subject: params[:subject],
                message_id: kind_of(String),
                timestamp: kind_of(Time),
                domain_id: domain.id,
                credential_id: credential.id,
                bounce: false,
                tag: params[:tag],
                headers: hash_including("x-test-header-1" => ["111"],
                                        "x-test-header-2" => ["222"],
                                        "sender" => [params[:sender]],
                                        "to" => ["test@example.com"],
                                        "cc" => ["cc@example.com"],
                                        "reply-to" => ["reply@example.com"]),
                plain_body: params[:plain_body],
                html_body: params[:html_body],
                attachments: [
                  have_attributes(content_type: /\Atext\/plain/, filename: "test1.txt", body: have_attributes(to_s: "hello world 1")),
                  have_attributes(content_type: /\Atext\/plain/, filename: "test2.txt", body: have_attributes(to_s: "hello world 2")),
                ]
              )
            end
          end
        end
      end
    end
  end
end
