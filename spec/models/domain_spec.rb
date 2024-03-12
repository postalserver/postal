# frozen_string_literal: true

# == Schema Information
#
# Table name: domains
#
#  id                     :integer          not null, primary key
#  dkim_error             :string(255)
#  dkim_identifier_string :string(255)
#  dkim_private_key       :text(65535)
#  dkim_status            :string(255)
#  dns_checked_at         :datetime
#  incoming               :boolean          default(TRUE)
#  mx_error               :string(255)
#  mx_status              :string(255)
#  name                   :string(255)
#  outgoing               :boolean          default(TRUE)
#  owner_type             :string(255)
#  return_path_error      :string(255)
#  return_path_status     :string(255)
#  spf_error              :string(255)
#  spf_status             :string(255)
#  use_for_any            :boolean
#  uuid                   :string(255)
#  verification_method    :string(255)
#  verification_token     :string(255)
#  verified_at            :datetime
#  created_at             :datetime
#  updated_at             :datetime
#  owner_id               :integer
#  server_id              :integer
#
# Indexes
#
#  index_domains_on_server_id  (server_id)
#  index_domains_on_uuid       (uuid)
#
require "rails_helper"

describe Domain do
  subject(:domain) { build(:domain) }

  describe "relationships" do
    it { is_expected.to belong_to(:server).optional }
    it { is_expected.to belong_to(:owner).optional }
    it { is_expected.to have_many(:routes) }
    it { is_expected.to have_many(:track_domains) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to([:owner_type, :owner_id]).case_insensitive.with_message("is already added") }
    it { is_expected.to allow_value("example.com").for(:name) }
    it { is_expected.to allow_value("example.co.uk").for(:name) }
    it { is_expected.to_not allow_value("EXAMPLE.COM").for(:name) }
    it { is_expected.to_not allow_value("example.com ").for(:name) }
    it { is_expected.to_not allow_value("example com").for(:name) }
    it { is_expected.to validate_inclusion_of(:verification_method).in_array(Domain::VERIFICATION_METHODS) }
  end

  describe "creation" do
    it "creates a new dkim identifier string" do
      expect { domain.save }.to change { domain.dkim_identifier_string }.from(nil).to(match(/\A[a-zA-Z0-9]{6}\z/))
    end

    it "generates a new dkim key" do
      expect { domain.save }.to change { domain.dkim_private_key }.from(nil).to(match(/\A-+BEGIN RSA PRIVATE KEY-+/))
    end

    it "generates a UUID" do
      expect { domain.save }.to change { domain.uuid }.from(nil).to(/[a-f0-9-]{36}/)
    end
  end

  describe ".verified" do
    it "returns verified domains only" do
      verified_domain = create(:domain)
      create(:domain, :unverified)
      expect(described_class.verified).to eq [verified_domain]
    end
  end

  context "when verification method changes" do
    context "to DNS" do
      let(:domain) { create(:domain, :unverified, verification_method: "Email") }

      it "generates a DNS suitable verification token" do
        domain.verification_method = "DNS"
        expect { domain.save }.to change { domain.verification_token }.from(match(/\A\d{6}\z/)).to(match(/\A[A-Za-z0-9+]{32}\z/))
      end
    end

    context "to Email" do
      let(:domain) { create(:domain, :unverified, verification_method: "DNS") }

      it "generates an email suitable verification token" do
        domain.verification_method = "Email"
        expect { domain.save }.to change { domain.verification_token }.from(match(/\A[A-Za-z0-9+]{32}\z/)).to(match(/\A\d{6}\z/))
      end
    end
  end

  describe "#verified?" do
    context "when the domain is verified" do
      it "returns true" do
        expect(domain.verified?).to be true
      end
    end

    context "when the domain is not verified" do
      let(:domain) { build(:domain, :unverified) }

      it "returns false" do
        expect(domain.verified?).to be false
      end
    end
  end

  describe "#mark_as_verified" do
    context "when already verified" do
      it "returns false" do
        expect(domain.mark_as_verified).to be false
      end
    end

    context "when unverified" do
      let(:domain) { create(:domain, :unverified) }

      it "sets the verification time" do
        expect { domain.mark_as_verified }.to change { domain.verified_at }.from(nil).to(kind_of(Time))
      end
    end
  end

  describe "#parent_domains" do
    context "at level 1" do
      let(:domain) { build(:domain, name: "example.com") }

      it "returns the current domain only" do
        expect(domain.parent_domains).to eq ["example.com"]
      end
    end

    context "at level 2" do
      let(:domain) { build(:domain, name: "test.example.com") }

      it "returns the current domain plus its parent" do
        expect(domain.parent_domains).to eq ["test.example.com", "example.com"]
      end
    end

    context "at level 3 (and higher)" do
      let(:domain) { build(:domain, name: "sub.test.example.com") }

      it "returns the current domain plus its parents" do
        expect(domain.parent_domains).to eq ["sub.test.example.com", "test.example.com", "example.com"]
      end
    end
  end

  describe "#generate_dkim_key" do
    it "generates a new dkim key" do
      expect { domain.generate_dkim_key }.to change { domain.dkim_private_key }.from(nil).to(match(/\A-+BEGIN RSA PRIVATE KEY-+/))
    end
  end

  describe "#dkim_key" do
    context "when the domain has a DKIM key" do
      let(:domain) { create(:domain) }

      it "returns the dkim key as a OpenSSL::PKey::RSA" do
        expect(domain.dkim_key).to be_a OpenSSL::PKey::RSA
        expect(domain.dkim_key.to_s).to eq domain.dkim_private_key
      end
    end

    context "when the domain has no DKIM key" do
      let(:domain) { build(:domain) }

      it "returns nil" do
        expect(domain.dkim_key).to be_nil
      end
    end
  end

  describe "#to_param" do
    context "when the domain has not been saved" do
      it "returns nil" do
        expect(domain.to_param).to be_nil
      end
    end
    context "when the domain has been saved" do
      before do
        domain.save
      end

      it "returns the UUID" do
        expect(domain.to_param).to eq domain.uuid
      end
    end
  end

  describe "#verification_email_addresses" do
    let(:domain) { build(:domain, name: "example.com") }

    it "returns the verification email addresses" do
      expect(domain.verification_email_addresses).to eq [
        "webmaster@example.com",
        "postmaster@example.com",
        "admin@example.com",
        "administrator@example.com",
        "hostmaster@example.com",
      ]
    end
  end

  describe "#spf_record" do
    it "returns the SPF record" do
      expect(domain.spf_record).to eq "v=spf1 a mx include:#{Postal::Config.dns.spf_include} ~all"
    end
  end

  describe "#dkim_record" do
    context "when the domain has no DKIM key" do
      it "returns nil" do
        expect(domain.dkim_record).to be_nil
      end
    end

    context "when the domain has a DKIM key" do
      before do
        domain.save
      end

      it "returns the DKIM record" do
        expect(domain.dkim_record).to match(/\Av=DKIM1; t=s; h=sha256; p=.*;\z/)
      end
    end
  end

  describe "#dkim_identifier" do
    context "when the domain has no dkim identifier string" do
      it "returns nil" do
        expect(domain.dkim_identifier).to be_nil
      end
    end

    context "when the domain has a dkim identifier string" do
      before do
        domain.save
      end

      it "returns the DKIM identifier" do
        expect(domain.dkim_identifier).to eq "#{Postal::Config.dns.dkim_identifier}-#{domain.dkim_identifier_string}"
      end
    end
  end

  describe "#dkim_record_name" do
    context "when the domain has no dkim identifier string" do
      it "returns nil" do
        expect(domain.dkim_record_name).to be_nil
      end
    end

    context "when the domain has a dkim identifier string" do
      before do
        domain.save
      end

      it "returns the DKIM identifier" do
        expect(domain.dkim_record_name).to eq "#{Postal::Config.dns.dkim_identifier}-#{domain.dkim_identifier_string}._domainkey"
      end
    end
  end

  describe "#return_path_domain" do
    it "returns the return path domain" do
      expect(domain.return_path_domain).to eq "#{Postal::Config.dns.custom_return_path_prefix}.#{domain.name}"
    end
  end

  describe "#dns_verification_string" do
    let(:domain) { create(:domain, verification_method: "DNS") }

    it "returns the DNS verification string" do
      expect(domain.dns_verification_string).to eq "#{Postal::Config.dns.domain_verify_prefix} #{domain.verification_token}"
    end
  end

  describe "#resolver" do
    context "when the local nameservers should be used" do
      before do
        allow(Postal::Config.postal).to receive(:use_local_ns_for_domain_verification?).and_return(true)
      end

      it "uses the local DNS" do
        expect(domain.resolver).to eq DNSResolver.local
      end
    end

    context "when local nameservers should not be used" do
      it "uses the a resolver for this domain" do
        allow(DNSResolver).to receive(:for_domain).with(domain.name).and_return(DNSResolver.new(["1.2.3.4"]))
        expect(domain.resolver).to be_a DNSResolver
        expect(domain.resolver.nameservers).to eq ["1.2.3.4"]
      end
    end
  end

  describe "#verify_with_dns" do
    context "when the verification method is not DNS" do
      let(:domain) { build(:domain, verification_method: "Email") }

      it "returns false" do
        expect(domain.verify_with_dns).to be false
      end
    end

    context "when a TXT record is found that matches" do
      let(:domain) { create(:domain, :unverified) }

      before do
        allow(domain.resolver).to receive(:txt).with(domain.name).and_return([domain.dns_verification_string])
      end

      it "returns true" do
        expect(domain.verify_with_dns).to be true
      end

      it "sets the verification time" do
        expect { domain.verify_with_dns }.to change { domain.verified_at }.from(nil).to(kind_of(Time))
      end
    end

    context "when no TXT record is found" do
      let(:domain) { create(:domain, :unverified) }

      before do
        allow(domain.resolver).to receive(:txt).with(domain.name).and_return(["something", "something else"])
      end

      it "returns false" do
        expect(domain.verify_with_dns).to be false
      end

      it "does not set the verification time" do
        expect { domain.verify_with_dns }.to_not change { domain.verified_at } # rubocop:disable Lint/AmbiguousBlockAssociation
      end
    end
  end
end
