# frozen_string_literal: true

require "rails_helper"

module SMTPClient

  RSpec.describe AddressPreferences do
    def with_preference(value)
      allow(Postal::Config.smtp_client).to receive(:address_preference).and_return(value)
    end

    describe ".current" do
      it "returns ipv6 by default" do
        expect(described_class.current).to eq "ipv6"
      end

      it "returns ipv4 when configured" do
        with_preference("ipv4")
        expect(described_class.current).to eq "ipv4"
      end

      it "returns ipv6_only when configured" do
        with_preference("ipv6_only")
        expect(described_class.current).to eq "ipv6_only"
      end

      it "returns ipv4_only when configured" do
        with_preference("ipv4_only")
        expect(described_class.current).to eq "ipv4_only"
      end

      it "is case and whitespace insensitive" do
        with_preference(" IPv4 ")
        expect(described_class.current).to eq "ipv4"
      end

      it "falls back to the default for unknown values" do
        with_preference("banana")
        expect(described_class.current).to eq "ipv6"
      end
    end

    describe ".prefer_ipv4?" do
      it "is false for ipv6" do
        with_preference("ipv6")
        expect(described_class.prefer_ipv4?).to be false
      end

      it "is true for ipv4" do
        with_preference("ipv4")
        expect(described_class.prefer_ipv4?).to be true
      end

      it "is false for ipv6_only" do
        with_preference("ipv6_only")
        expect(described_class.prefer_ipv4?).to be false
      end

      it "is true for ipv4_only" do
        with_preference("ipv4_only")
        expect(described_class.prefer_ipv4?).to be true
      end
    end

    describe ".fallback?" do
      it "is true for ipv6" do
        with_preference("ipv6")
        expect(described_class.fallback?).to be true
      end

      it "is true for ipv4" do
        with_preference("ipv4")
        expect(described_class.fallback?).to be true
      end

      it "is false for ipv6_only" do
        with_preference("ipv6_only")
        expect(described_class.fallback?).to be false
      end

      it "is false for ipv4_only" do
        with_preference("ipv4_only")
        expect(described_class.fallback?).to be false
      end
    end
  end

end
