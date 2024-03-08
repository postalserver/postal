# frozen_string_literal: true

require "rails_helper"

module SMTPServer

  describe Client do
    let(:ip_address) { "1.2.3.4" }
    subject(:client) { described_class.new(ip_address) }

    before do
      client.handle("HELO test.example.com")
    end

    describe "AUTH PLAIN" do
      context "when no credentials are provided on the initial data" do
        it "returns a 334" do
          expect(client.handle("AUTH PLAIN")).to eq("334")
        end

        it "accepts the username and password from the next input" do
          client.handle("AUTH PLAIN")
          credential = create(:credential, type: "SMTP")
          expect(client.handle(credential.to_smtp_plain)).to match(/235 Granted for/)
        end
      end

      context "when valid credentials are provided on one line" do
        it "authenticates and returns a response" do
          credential = create(:credential, type: "SMTP")
          expect(client.handle("AUTH PLAIN #{credential.to_smtp_plain}")).to match(/235 Granted for/)
          expect(client.credential).to eq credential
        end
      end

      context "when invalid credentials are provided" do
        it "returns an error and resets the state" do
          base64 = Base64.encode64("user\0pass")
          expect(client.handle("AUTH PLAIN #{base64}")).to eq("535 Invalid credential")
          expect(client.state).to eq :welcomed
        end
      end

      context "when username or password is missing" do
        it "returns an error and resets the state" do
          base64 = Base64.encode64("pass")
          expect(client.handle("AUTH PLAIN #{base64}")).to eq("535 Authenticated failed - protocol error")
          expect(client.state).to eq :welcomed
        end
      end
    end

    describe "AUTH LOGIN" do
      context "when no username is provided on the first line" do
        it "requests the username" do
          expect(client.handle("AUTH LOGIN")).to eq("334 VXNlcm5hbWU6")
        end

        it "requests a password after a username" do
          client.handle("AUTH LOGIN")
          expect(client.handle("xx")).to eq("334 UGFzc3dvcmQ6")
        end

        it "authenticates and returns a response if the password is correct" do
          client.handle("AUTH LOGIN")
          client.handle("xx")
          credential = create(:credential, type: "SMTP")
          password = Base64.encode64(credential.key)
          expect(client.handle(password)).to match(/235 Granted for/)
        end

        it "returns an error when an invalid credential is provided" do
          client.handle("AUTH LOGIN")
          client.handle("xx")
          password = Base64.encode64("xx")
          expect(client.handle(password)).to eq("535 Invalid credential")
        end
      end

      context "when a username is provided on the first line" do
        it "requests a password" do
          username = Base64.encode64("xx")
          expect(client.handle("AUTH LOGIN #{username}")).to eq("334 UGFzc3dvcmQ6")
        end

        it "authenticates and returns a response" do
          credential = create(:credential, type: "SMTP")
          username = Base64.encode64("xx")
          password = Base64.encode64(credential.key)
          expect(client.handle("AUTH LOGIN #{username}")).to eq("334 UGFzc3dvcmQ6")
          expect(client.handle(password)).to match(/235 Granted for/)
          expect(client.credential).to eq credential
        end

        it "returns an error and resets the state" do
          username = Base64.encode64("xx")
          password = Base64.encode64("xx")
          expect(client.handle("AUTH LOGIN #{username}")).to eq("334 UGFzc3dvcmQ6")
          expect(client.handle(password)).to eq("535 Invalid credential")
          expect(client.state).to eq :welcomed
        end
      end
    end

    describe "AUTH CRAM-MD5" do
      context "when valid credentials are provided" do
        it "authenticates and returns a response" do
          credential = create(:credential, type: "SMTP")
          result = client.handle("AUTH CRAM-MD5")
          expect(result).to match(/\A334 [A-Za-z0-9=]+\z/)
          challenge = Base64.decode64(result.split[1])
          password = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("md5"), credential.key, challenge)
          base64 = Base64.encode64("#{credential.server.organization.permalink}/#{credential.server.permalink} #{password}")
          expect(client.handle(base64)).to match(/235 Granted for/)
          expect(client.credential).to eq credential
        end
      end

      context "when no org/server matches the provided username" do
        it "returns an error" do
          client.handle("AUTH CRAM-MD5")
          base64 = Base64.encode64("org/server password")
          expect(client.handle(base64)).to eq "535 Denied"
        end
      end

      context "when invalid credentials are provided" do
        it "returns an error and resets the state" do
          server = create(:server)
          base64 = Base64.encode64("#{server.organization.permalink}/#{server.permalink} invalid-password")
          client.handle("AUTH CRAM-MD5")
          expect(client.handle(base64)).to eq("535 Denied")
        end
      end
    end
  end

end
