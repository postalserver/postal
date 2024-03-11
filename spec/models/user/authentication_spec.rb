# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  describe ".authenticate" do
    it "does not authenticate users with invalid emails" do
      expect { User.authenticate("nothing@nothing.com", "hello") }.to raise_error(Postal::Errors::AuthenticationError) do |e|
        expect(e.error).to eq "InvalidEmailAddress"
      end
    end

    it "does not authenticate users with invalid passwords" do
      user = create(:user)
      expect { User.authenticate(user.email_address, "hello") }.to raise_error(Postal::Errors::AuthenticationError) do |e|
        expect(e.error).to eq "InvalidPassword"
      end
    end

    it "authenticates valid users" do
      user = create(:user)
      auth_user = nil
      expect { auth_user = User.authenticate(user.email_address, "passw0rd") }.to_not raise_error
      expect(auth_user).to eq user
    end
  end
end
