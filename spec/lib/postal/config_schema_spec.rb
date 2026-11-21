# frozen_string_literal: true

require "rails_helper"
require "konfig/error"
require "konfig/sources/abstract"

module Postal
  RSpec.describe ConfigSchema do
    let(:schema) { described_class }

    class TestConfigSource < Konfig::Sources::Abstract
      def initialize(config)
        super()
        @config = config
      end

      def get(path, attribute: nil)
        value = path.reduce(@config) do |memo, key|
          next nil unless memo.is_a?(Hash)

          memo[key] || memo[key.to_s] || memo[key.to_sym]
        end
        raise Konfig::ValueNotPresentError if value.nil?

        value
      end
    end

    def build_config(smtp_relays)
      Konfig::Config.build(
        schema,
        sources: [
          TestConfigSource.new(
            "postal" => {
              "smtp_relays" => smtp_relays
            }
          )
        ]
      )
    end

    describe "postal.smtp_relays" do
      it "parses relay URLs without credentials" do
        config = build_config(["smtp://relay.example.com:587?ssl_mode=TLS"])

        expect(config.postal.smtp_relays).to eq [
          { "host" => "relay.example.com", "port" => 587, "ssl_mode" => "TLS" },
        ]
      end

      it "parses relay URLs with credentials" do
        config = build_config(["smtp://relay-user:relay-pass@relay.example.com:587?ssl_mode=TLS"])

        expect(config.postal.smtp_relays).to eq [
          { "host" => "relay.example.com", "port" => 587, "ssl_mode" => "TLS", "username" => "relay-user", "password" => "relay-pass" },
        ]
      end

      it "decodes percent-encoded relay credentials" do
        config = build_config(["smtp://relay%40user:pa%24%24%3Aword@relay.example.com:587?ssl_mode=TLS"])

        expect(config.postal.smtp_relays).to eq [
          { "host" => "relay.example.com", "port" => 587, "ssl_mode" => "TLS", "username" => "relay@user", "password" => "pa$$:word" },
        ]
      end
    end
  end
end
