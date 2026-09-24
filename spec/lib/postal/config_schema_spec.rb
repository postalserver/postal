# frozen_string_literal: true

require "rails_helper"

module Postal

  #
  # Serves a list of relay URLs, so the schema's transformation of them can be
  # asserted without a configuration file on disk.
  #
  class SmtpRelaySource < Konfig::Sources::Abstract

    def initialize(relays)
      super()
      @relays = relays
    end

    def get(path, attribute: nil)
      raise Konfig::ValueNotPresentError unless path.join(".") == "postal.smtp_relays"

      @relays
    end

  end

  RSpec.describe ConfigSchema do
    subject(:config) { Konfig::Config.build(described_class, sources: [SmtpRelaySource.new(relays)]) }

    let(:relay) { config.postal.smtp_relays.first }

    describe "postal.smtp_relays" do
      context "when a relay URL carries credentials and a mechanism" do
        let(:relays) do
          ["smtp://sm%40il:p%3Ass%2Bword@relay.example.com:587?ssl_mode=STARTTLS&auth=login"]
        end

        it "decodes them, so a password containing a colon or a plus arrives intact" do
          expect(relay["username"]).to eq "sm@il"
          expect(relay["password"]).to eq "p:ss+word"
        end

        it "takes the mechanism from the URL" do
          expect(relay["auth_mode"]).to eq "login"
        end

        it "keeps the host, port and SSL mode" do
          expect(relay["host"]).to eq "relay.example.com"
          expect(relay["port"]).to eq 587
          expect(relay["ssl_mode"]).to eq "STARTTLS"
        end
      end

      context "when a relay URL carries a mechanism but no credentials" do
        let(:relays) { ["smtp://relay.example.com:587?auth=cram_md5"] }

        it "records the mechanism without inventing a credential" do
          expect(relay["auth_mode"]).to eq "cram_md5"
          expect(relay).not_to have_key("username")
          expect(relay).not_to have_key("password")
        end
      end

      context "when a relay URL names only a host and a port" do
        let(:relays) { ["smtp://1.2.3.4:25"] }

        it "defaults the SSL mode" do
          expect(relay["ssl_mode"]).to eq "Auto"
        end

        it "carries the three keys every relay has and no more" do
          expect(relay.keys).to contain_exactly("host", "port", "ssl_mode")
        end
      end

      context "when a relay URL names no port" do
        let(:relays) { ["smtp://relay.example.com"] }

        it "assumes port 25" do
          expect(relay["port"]).to eq 25
        end
      end
    end

    describe "smtp_client.mta_sts" do
      let(:relays) { [] }

      it "is on by default, so a domain which publishes a policy is protected without configuration" do
        expect(config.smtp_client.mta_sts?).to be true
      end
    end
  end

end
