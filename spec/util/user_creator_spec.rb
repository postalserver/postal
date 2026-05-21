# frozen_string_literal: true

require "rails_helper"

describe UserCreator do
  let(:env) do
    {
      "POSTAL_INITIAL_USER_EMAIL" => "first-admin@example.com",
      "POSTAL_INITIAL_USER_FIRST_NAME" => "First",
      "POSTAL_INITIAL_USER_LAST_NAME" => "Admin",
      "POSTAL_INITIAL_USER_PASSWORD" => "correct-horse-battery-staple"
    }
  end

  describe ".start (non-interactive mode)" do
    before { stub_const("ENV", ENV.to_hash.merge(env)) }

    context "when POSTAL_INITIAL_USER_EMAIL is set and the user does not exist" do
      it "creates the user with the values from the environment" do
        expect { described_class.start }.to change(User, :count).by(1)
        user = User.find_by(email_address: "first-admin@example.com")
        expect(user.first_name).to eq("First")
        expect(user.last_name).to eq("Admin")
        expect(user.authenticate("correct-horse-battery-staple")).to be_truthy
      end

      it "yields the user to the block before saving" do
        described_class.start do |u|
          u.admin = true
          u.email_verified_at = Time.now
        end
        user = User.find_by(email_address: "first-admin@example.com")
        expect(user.admin).to be true
        expect(user.email_verified_at).to be_present
      end
    end

    context "when a user with that email already exists" do
      let!(:existing) do
        create(:user,
               email_address: "first-admin@example.com",
               first_name: "Old",
               last_name: "Name",
               password: "old-password",
               admin: false)
      end

      it "updates the existing user (does not create a new one)" do
        expect { described_class.start { |u| u.admin = true } }.not_to change(User, :count)
        existing.reload
        expect(existing.first_name).to eq("First")
        expect(existing.last_name).to eq("Admin")
        expect(existing.admin).to be true
        expect(existing.authenticate("correct-horse-battery-staple")).to be_truthy
      end
    end

    context "when one of the required env vars is missing" do
      it "exits non-zero and reports the missing var" do
        stub_const("ENV", ENV.to_hash.merge(env).merge("POSTAL_INITIAL_USER_PASSWORD" => ""))
        expect {
          expect { described_class.start }.to output(/POSTAL_INITIAL_USER_PASSWORD/).to_stderr
        }.to raise_error(SystemExit)
      end
    end

    context "when validation fails (e.g. malformed email)" do
      it "exits non-zero and prints the validation errors" do
        stub_const("ENV", ENV.to_hash.merge(env).merge("POSTAL_INITIAL_USER_EMAIL" => "no-at-sign"))
        expect {
          expect { described_class.start }.to output(/Failed to create user/).to_stderr
        }.to raise_error(SystemExit)
      end
    end
  end

  describe ".start (interactive mode)" do
    # The HighLine prompts are exercised by manual testing; we only verify
    # here that the interactive branch is selected when the env var is absent.
    before { stub_const("ENV", ENV.to_hash.reject { |k, _| k.start_with?("POSTAL_INITIAL_USER_") }) }

    it "uses HighLine when POSTAL_INITIAL_USER_EMAIL is not set" do
      expect(HighLine).to receive(:new).and_call_original
      # Stub HighLine#ask to short-circuit the prompts.
      allow_any_instance_of(HighLine).to receive(:ask).and_return("ignored")
      # We expect the save to fail because the email is "ignored", but that's
      # fine — the assertion is that we entered the interactive code path.
      described_class.start
    end
  end
end
