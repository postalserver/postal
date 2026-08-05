# frozen_string_literal: true

require "rails_helper"

RSpec.describe HTTPEndpoint do
  describe "validations" do
    subject(:endpoint) { build(:http_endpoint, url: url) }

    [
      "https://example.com/messages/~user;v=1?token=a+b#section",
      "http://example.com:8080/path?x=1&y=2",
      "https://[2606:2800:220:1:248:1893:25c8:1946]/hook",
    ].each do |valid_url|
      context "with #{valid_url}" do
        let(:url) { valid_url }

        it "is valid" do
          expect(endpoint).to be_valid
        end
      end
    end

    [
      "ftp://example.com/hook",
      "https:///missing-host",
      "not a url",
    ].each do |invalid_url|
      context "with #{invalid_url}" do
        let(:url) { invalid_url }

        it "is invalid" do
          expect(endpoint).not_to be_valid
          expect(endpoint.errors[:url]).to be_present
        end
      end
    end
  end
end
