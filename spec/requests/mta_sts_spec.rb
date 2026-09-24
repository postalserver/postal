# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MTA-STS policy" do
  let(:organization) { create(:organization) }
  let(:domain) { create(:domain, owner: organization, mta_sts_mode: "enforce") }

  context "when a policy is served" do
    before do
      host! "mta-sts.#{domain.name}"
    end

    it "returns the policy as plain text" do
      get "/.well-known/mta-sts.txt"
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq "text/plain"
      expect(response.body).to eq domain.mta_sts_policy
    end

    it "serves the policy directly rather than redirecting" do
      get "/.well-known/mta-sts.txt"
      expect(response).to_not be_redirect
    end
  end

  context "when the domain has no policy" do
    let(:domain) { create(:domain, owner: organization, mta_sts_mode: "none") }

    before do
      host! "mta-sts.#{domain.name}"
    end

    it "returns not found" do
      get "/.well-known/mta-sts.txt"
      expect(response).to have_http_status(:not_found)
    end
  end

  context "when the domain is not known" do
    before do
      host! "mta-sts.unknown-domain.example"
    end

    it "returns not found" do
      get "/.well-known/mta-sts.txt"
      expect(response).to have_http_status(:not_found)
    end
  end

  context "when the request does not use an MTA-STS host" do
    before do
      host! Postal::Config.postal.web_hostname
    end

    it "returns not found" do
      get "/.well-known/mta-sts.txt"
      expect(response).to have_http_status(:not_found)
    end
  end

  context "when the domain's policy has a maximum age" do
    let(:domain) { create(:domain, owner: organization, mta_sts_mode: "testing", mta_sts_max_age: 604_800) }

    before do
      host! "mta-sts.#{domain.name}"
    end

    it "includes it in the served policy" do
      get "/.well-known/mta-sts.txt"
      expect(response.body).to include "max_age: 604800"
    end
  end
end
