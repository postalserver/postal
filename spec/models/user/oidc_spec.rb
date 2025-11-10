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
      allow(Postal::Config.oidc).to receive(:uid_field).and_return("sub")
      allow(Postal::Config.oidc).to receive(:name_field).and_return("name")
      allow(Postal::Config.oidc).to receive(:auto_create_users?).and_return(false)
      allow(Postal::Config.oidc).to receive(:auto_create_organization?).and_return(false)
      allow(Postal::Config.oidc).to receive(:auto_created_organization_name).and_return("My organization")
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

      context "when the OIDC name contains a single word" do
        let(:oidc_name) { "johnny" }

        it "duplicates the value for the last name" do
          result
          @existing_user.reload
          expect(@existing_user.first_name).to eq "johnny"
          expect(@existing_user.last_name).to eq "johnny"
        end
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
        context "and auto creation is disabled" do
          it "returns nil" do
            expect(result).to be_nil
          end

          it "logs" do
            result
            expect(logger).to have_logged(/no user with UID abcdef/)
            expect(logger).to have_logged(/no user with e-mail address/)
          end
        end

        context "and auto creation is enabled" do
          before do
            allow(Postal::Config.oidc).to receive(:auto_create_users?).and_return(true)
          end

          it "creates a new user" do
            expect { result }.to change(User, :count).by(1)
            expect(result.email_address).to eq oidc_email
            expect(result.oidc_uid).to eq uid
            expect(result.oidc_issuer).to eq issuer
            expect(result.first_name).to eq "John"
            expect(result.last_name).to eq "Smith"
          end

          it "logs the creation" do
            result
            expect(logger).to have_logged(/OIDC auto user creation succeeded/i)
          end

          context "when no name is provided" do
            let(:oidc_name) { nil }

            it "derives a name from the e-mail address" do
              expect(result.first_name).to eq "test"
              expect(result.last_name).to eq "test"
            end
          end

          context "when no e-mail is provided" do
            let(:oidc_email) { nil }

            it "cannot create a user" do
              expect(result).to be_nil
              expect(logger).to have_logged(/no e-mail address provided/)
            end
          end

          context "when organization auto creation is enabled" do
            let(:organization_name) { "My organization" }

            before do
              allow(Postal::Config.oidc).to receive(:auto_create_organization?).and_return(true)
              allow(Postal::Config.oidc).to receive(:auto_created_organization_name).and_return(organization_name)
            end

            it "creates an organization owned by the new user" do
              expect { result }.to change(Organization, :count).by(1)
              organization = Organization.last
              expect(organization.name).to eq organization_name
              expect(organization.owner).to eq result
              expect(result.organizations).to include(organization)
              expect(organization.organization_users.first.user).to eq result
              expect(organization.organization_users.first.admin).to be true
            end
          end
        end
      end
    end
  end
end
