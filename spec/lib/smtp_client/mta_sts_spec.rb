# frozen_string_literal: true

require "rails_helper"

RSpec.describe SMTPClient::MTASts do
  let(:domain) { "example.com" }
  let(:policy_url) { "https://mta-sts.example.com/.well-known/mta-sts.txt" }
  let(:txt_records) { ["v=STSv1; id=20240101"] }
  let(:policy_text) do
    <<~POLICY
      version: STSv1
      mode: enforce
      max_age: 86400
      mx: mx1.example.com
      mx: mx2.example.com
    POLICY
  end

  before do
    SMTPClient::MTASts.clear!
    allow(DNSResolver.local).to receive(:txt).with("_mta-sts.#{domain}").and_return(txt_records)
    stub_request(:get, policy_url).to_return(status: 200, body: policy_text)
  end

  describe ".policy_for" do
    it "returns the policy the domain publishes, over https" do
      policy = described_class.policy_for(domain)

      expect(policy).to be_enforce
      expect(policy.max_age).to eq 86_400
      expect(policy.mx).to eq ["mx1.example.com", "mx2.example.com"]
      expect(a_request(:get, policy_url)).to have_been_made.once
    end

    it "does not fetch the policy again while the record is unchanged and the policy is current" do
      described_class.policy_for(domain)
      described_class.policy_for(domain)

      expect(a_request(:get, policy_url)).to have_been_made.once
    end

    it "fetches the policy again when the id in the record changes" do
      described_class.policy_for(domain)
      allow(DNSResolver.local).to receive(:txt).with("_mta-sts.#{domain}")
                                               .and_return(["v=STSv1; id=20240202"])
      described_class.policy_for(domain)

      expect(a_request(:get, policy_url)).to have_been_made.twice
    end

    context "when the domain publishes no mta-sts record" do
      let(:txt_records) { [] }

      it "returns nil without fetching a policy" do
        expect(described_class.policy_for(domain)).to be_nil
        expect(a_request(:get, policy_url)).not_to have_been_made
      end
    end

    context "when the record is not an mta-sts record" do
      let(:txt_records) { ["v=spf1 include:example.net -all"] }

      it "returns nil" do
        expect(described_class.policy_for(domain)).to be_nil
      end
    end

    context "when the policy cannot be fetched" do
      before { stub_request(:get, policy_url).to_return(status: 404, body: "not found") }

      it "returns nil rather than raising" do
        expect(described_class.policy_for(domain)).to be_nil
      end

      it "warns about the answer it got" do
        expect(Postal.logger).to receive(:warn).with(/answered 404/)
        described_class.policy_for(domain)
      end
    end

    context "when the policy is not usable" do
      let(:policy_text) { "version: STSv1\nmode: enforce\n" }

      it "returns nil" do
        expect(described_class.policy_for(domain)).to be_nil
      end
    end

    context "when mta-sts is disabled" do
      before { allow(Postal::Config.smtp_client).to receive(:mta_sts?).and_return(false) }

      it "returns nil without looking the domain up" do
        expect(described_class.policy_for(domain)).to be_nil
        expect(DNSResolver.local).not_to have_received(:txt)
      end
    end
  end

  describe SMTPClient::MTASts::Policy do
    describe ".parse" do
      it "reads the mode, the max_age and the hosts" do
        policy = described_class.parse(policy_text)

        expect(policy.mode).to eq "enforce"
        expect(policy.max_age).to eq 86_400
        expect(policy.mx).to eq ["mx1.example.com", "mx2.example.com"]
      end

      it "is not enforcing when the mode is testing" do
        expect(described_class.parse("version: STSv1\nmode: testing\nmax_age: 86400\nmx: mx1.example.com\n"))
          .not_to be_enforce
      end

      it "returns nil without a version" do
        expect(described_class.parse("mode: enforce\nmax_age: 86400\nmx: mx1.example.com\n")).to be_nil
      end

      it "returns nil for a mode it does not know" do
        expect(described_class.parse("version: STSv1\nmode: strict\nmax_age: 86400\nmx: mx1.example.com\n"))
          .to be_nil
      end

      it "returns nil without a positive max_age" do
        expect(described_class.parse("version: STSv1\nmode: enforce\nmax_age: 0\nmx: mx1.example.com\n"))
          .to be_nil
      end

      it "returns nil when an enforcing policy lists no host" do
        expect(described_class.parse("version: STSv1\nmode: enforce\nmax_age: 86400\n")).to be_nil
      end

      it "accepts a none policy without hosts" do
        expect(described_class.parse("version: STSv1\nmode: none\nmax_age: 86400\n")).not_to be_nil
      end

      it "ignores blank lines, unknown keys and the case of a host" do
        policy = described_class.parse(
          "\nversion: STSv1\n\nunknown: x\nmode: enforce\nmax_age: 86400\nmx: MX1.Example.COM.\n"
        )

        expect(policy.mx).to eq ["mx1.example.com"]
      end
    end

    describe "#publishes_mx?" do
      subject(:policy) { described_class.parse(policy_text) }

      it "matches a listed host whatever its case or trailing dot" do
        expect(policy.publishes_mx?("MX1.EXAMPLE.COM.")).to be true
      end

      it "does not match a host it does not list" do
        expect(policy.publishes_mx?("mx9.example.com")).to be false
      end
    end
  end
end
