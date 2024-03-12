# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                               :integer          not null, primary key
#  admin                            :boolean          default(FALSE)
#  email_address                    :string(255)
#  email_verification_token         :string(255)
#  email_verified_at                :datetime
#  first_name                       :string(255)
#  last_name                        :string(255)
#  oidc_issuer                      :string(255)
#  oidc_uid                         :string(255)
#  password_digest                  :string(255)
#  password_reset_token             :string(255)
#  password_reset_token_valid_until :datetime
#  time_zone                        :string(255)
#  uuid                             :string(255)
#  created_at                       :datetime
#  updated_at                       :datetime
#
# Indexes
#
#  index_users_on_email_address  (email_address)
#  index_users_on_uuid           (uuid)
#
require "rails_helper"

describe User do
  subject(:user) { build(:user) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:email_address) }
    it { is_expected.to validate_presence_of(:password) }
    it { is_expected.to validate_uniqueness_of(:email_address).case_insensitive }
    it { is_expected.to allow_value("test@example.com").for(:email_address) }
    it { is_expected.to allow_value("test@example.co.uk").for(:email_address) }
    it { is_expected.to allow_value("test+tagged@example.co.uk").for(:email_address) }
    it { is_expected.to allow_value("test+tagged@EXAMPLE.COM").for(:email_address) }
    it { is_expected.to_not allow_value("test+tagged").for(:email_address) }
    it { is_expected.to_not allow_value("test.com").for(:email_address) }

    it "does not require a password when OIDC is enabled" do
      allow(Postal::Config.oidc).to receive(:enabled?).and_return(true)
      user.password = nil
      expect(user.save).to be true
    end
  end

  describe "relationships" do
    it { is_expected.to have_many(:organization_users) }
    it { is_expected.to have_many(:organizations) }
  end

  describe "creation" do
    before { user.save }

    it "should have a UUID" do
      expect(user.uuid).to be_a String
      expect(user.uuid.length).to eq 36
    end

    it "has a default timezone" do
      expect(user.time_zone).to eq "UTC"
    end
  end

  describe "#organizations_scope" do
    context "when the user is an admin" do
      it "returns a scope of all organizations" do
        user.admin = true
        scope = user.organizations_scope
        expect(scope).to eq Organization.present
      end
    end

    context "when the user not an admin" do
      it "returns a scope including only orgs the user is associated with" do
        user.admin = false
        user.organizations << create(:organization)
        scope = user.organizations_scope
        expect(scope).to eq user.organizations.present
      end
    end
  end

  describe "#name" do
    it "returns the name" do
      user.first_name = "John"
      user.last_name = "Doe"
      expect(user.name).to eq "John Doe"
    end
  end

  describe "#password?" do
    it "returns true if the user has a password" do
      user.password = "password"
      expect(user.password?).to be true
    end

    it "returns false if the user does not have a password" do
      user.password = nil
      expect(user.password?).to be false
    end
  end

  describe "#to_param" do
    it "returns the UUID" do
      user.uuid = "123"
      expect(user.to_param).to eq "123"
    end
  end

  describe "#email_tag" do
    it "returns the name and email address" do
      user.first_name = "John"
      user.last_name = "Doe"
      user.email_address = "john@example.com"
      expect(user.email_tag).to eq "John Doe <john@example.com>"
    end
  end

  describe ".[]" do
    it "should find a user by email address" do
      user = create(:user)
      expect(User[user.email_address]).to eq user
    end
  end
end
