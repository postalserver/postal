# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  let(:user) { build(:user) }

  describe "#oidc?" do
    it "returns true if the user has an OIDC UID" do
      user.oidc_uid = "123"
      expect(user.oidc?).to be true
    end

    it "returns false if the user does not have an OIDC UID" do
      user.oidc_uid = nil
      expect(user.oidc?).to be false
    end
  end

  describe ".find_from_oidc" do
    let(:issuer) { "https://identity.example.com" }

    before do
      allow(Postal::Config.oidc).to receive(:enabled?).and_return(true)
      allow(Postal::Config.oidc).to receive(:issuer).and_return(issuer)
      allow(Postal::Config.oidc).to receive(:email_address_field).and_return("email")
    end

    let(:uid) { "abcdef" }
    let(:oidc_name) { "John Smith" }
    let(:oidc_email) { "test@example.com" }

    let(:auth) { { "sub" => uid, "email" => oidc_email, "name" => oidc_name } }
    let(:logger) { TestLogger.new }

    subject(:result) { described_class.find_from_oidc(auth, logger: logger) }

    context "when there is a user that matchers the UID and issuer" do
      before do
        @existing_user = create(:user, oidc_uid: uid, oidc_issuer: issuer, first_name: "mary",
                                       last_name: "apples", email_address: "mary@apples.com")
      end

      it "returns that user" do
        expect(result).to eq @existing_user
      end

      it "updates the name and email address" do
        result
        @existing_user.reload
        expect(@existing_user.first_name).to eq "John"
        expect(@existing_user.last_name).to eq "Smith"
        expect(@existing_user.email_address).to eq "test@example.com"
      end

      it "logs" do
        result
        expect(logger).to have_logged(/found user with UID abcdef/i)
      end
    end

    context "when there is no user which matches the UID and issuer" do
      context "when there is a user which matches the email address without an OIDC UID" do
        before do
          @existing_user = create(:user, first_name: "mary",
                                         last_name: "apples", email_address: "test@example.com")
        end

        it "returns that user" do
          expect(result).to eq @existing_user
        end

        it "adds the UID and issuer to the user" do
          result
          @existing_user.reload
          expect(@existing_user.oidc_uid).to eq uid
          expect(@existing_user.oidc_issuer).to eq issuer
        end

        it "updates the name if changed" do
          result
          @existing_user.reload
          expect(@existing_user.first_name).to eq "John"
          expect(@existing_user.last_name).to eq "Smith"
        end

        it "removes the password" do
          @existing_user.password = "password"
          @existing_user.save!
          result
          @existing_user.reload
          expect(@existing_user.password_digest).to be_nil
        end

        it "logs" do
          result
          expect(logger).to have_logged(/no user with UID abcdef/)
          expect(logger).to have_logged(/found user with e-mail address test@example.com/)
        end
      end

      context "when there is no user which matches the email address" do
        it "returns nil" do
          expect(result).to be_nil
        end

        it "logs" do
          result
          expect(logger).to have_logged(/no user with UID abcdef/)
          expect(logger).to have_logged(/no user with e-mail address/)
        end
      end
    end
  end
end
