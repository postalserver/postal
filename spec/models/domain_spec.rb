# frozen_string_literal: true

# == Schema Information
#
# Table name: domains
#
#  id                             :integer          not null, primary key
#  dkim_error                     :string(255)
#  dkim_identifier_string         :string(255)
#  dkim_private_key               :text(65535)
#  dkim_status                    :string(255)
#  dns_checked_at                 :datetime
#  incoming                       :boolean          default(TRUE)
#  mx_error                       :string(255)
#  mx_status                      :string(255)
#  name                           :string(255)
#  outgoing                       :boolean          default(TRUE)
#  owner_type                     :string(255)
#  pending_dkim_identifier_string :string(255)
#  pending_dkim_private_key       :text(65535)
#  return_path_error              :string(255)
#  return_path_status             :string(255)
#  spf_error                      :string(255)
#  spf_status                     :string(255)
#  use_for_any                    :boolean
#  uuid                           :string(255)
#  verification_method            :string(255)
#  verification_token             :string(255)
#  verified_at                    :datetime
#  created_at                     :datetime
#  updated_at                     :datetime
#  owner_id                       :integer
#  server_id                      :integer
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

    it "generates a key of the configured size" do
      domain.generate_dkim_key
      expect(OpenSSL::PKey::RSA.new(domain.dkim_private_key).n.num_bits).to eq Postal::Config.dns.dkim_key_size
    end

    context "when a different key size is configured" do
      before do
        allow(Postal::Config.dns).to receive(:dkim_key_size).and_return(1024)
      end

      it "generates a key of that size" do
        domain.generate_dkim_key
        expect(OpenSSL::PKey::RSA.new(domain.dkim_private_key).n.num_bits).to eq 1024
      end
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

  describe "#pending_dkim_key" do
    context "when the domain has a pending DKIM key" do
      let(:domain) { create(:domain, dkim_status: "OK") }

      before do
        domain.regenerate_dkim_key!
      end

      it "returns the pending dkim key as a OpenSSL::PKey::RSA" do
        expect(domain.pending_dkim_key).to be_a OpenSSL::PKey::RSA
        expect(domain.pending_dkim_key.to_s).to eq domain.pending_dkim_private_key
      end
    end

    context "when the domain has no pending DKIM key" do
      let(:domain) { create(:domain) }

      it "returns nil" do
        expect(domain.pending_dkim_key).to be_nil
      end
    end
  end

  describe "#regenerate_dkim_key!" do
    context "when the current DKIM record is verified" do
      let(:domain) { create(:domain, dkim_status: "OK") }

      it "stores the new key as a pending key with a new identifier" do
        domain.regenerate_dkim_key!
        expect(domain.pending_dkim_private_key).to match(/\A-+BEGIN RSA PRIVATE KEY-+/)
        expect(domain.pending_dkim_identifier_string).to be_present
        expect(domain.pending_dkim_identifier_string).to_not eq domain.dkim_identifier_string
      end

      it "does not change the active key or status" do
        expect { domain.regenerate_dkim_key! }.to_not(change { domain.reload.dkim_private_key })
        expect(domain.dkim_status).to eq "OK"
      end
    end

    context "when the current DKIM record is not verified" do
      let(:domain) { create(:domain, dkim_status: "Missing", dkim_error: "No TXT records") }

      it "replaces the active key immediately without creating a pending key" do
        original_key = domain.dkim_key.to_s
        domain.regenerate_dkim_key!
        expect(domain.reload.dkim_private_key).to_not eq original_key
        expect(domain.pending_dkim_private_key).to be_nil
        expect(domain.dkim_key.to_s).to eq domain.dkim_private_key
      end

      it "resets the DKIM status" do
        domain.regenerate_dkim_key!
        expect(domain.dkim_status).to be_nil
        expect(domain.dkim_error).to be_nil
      end

      context "when a key change was already in progress" do
        # This happens when the active record breaks (so the status is no longer
        # "OK") while a pending key is waiting to be activated. The immediate
        # replacement supersedes the in-flight change, so the stale pending key
        # must not be left behind to be activated later.
        let(:domain) { create(:domain, dkim_status: "OK") }

        before do
          domain.regenerate_dkim_key!
          domain.update!(dkim_status: "Missing", dkim_error: "No TXT records")
        end

        it "abandons the pending key" do
          expect(domain.pending_dkim_private_key).to_not be_nil
          domain.regenerate_dkim_key!
          expect(domain.reload.pending_dkim_private_key).to be_nil
          expect(domain.pending_dkim_identifier_string).to be_nil
          expect(domain.pending_dkim_key).to be_nil
        end

        it "replaces the active key rather than promoting the pending one" do
          stale_pending_key = domain.pending_dkim_private_key
          original_key = domain.dkim_private_key
          domain.regenerate_dkim_key!
          expect(domain.reload.dkim_private_key).to_not eq original_key
          expect(domain.dkim_private_key).to_not eq stale_pending_key
        end
      end
    end
  end

  describe "#activate_pending_dkim_key" do
    context "when there is no pending key" do
      let(:domain) { create(:domain) }

      it "does nothing" do
        expect { domain.activate_pending_dkim_key }.to_not(change { domain.dkim_private_key })
      end
    end

    context "when there is a pending key" do
      let(:domain) { create(:domain, dkim_status: "OK") }

      before do
        domain.regenerate_dkim_key!
      end

      it "promotes the pending key and identifier and clears the pending values" do
        pending_key = domain.pending_dkim_private_key
        pending_identifier = domain.pending_dkim_identifier_string
        domain.activate_pending_dkim_key
        expect(domain.dkim_private_key).to eq pending_key
        expect(domain.dkim_identifier_string).to eq pending_identifier
        expect(domain.pending_dkim_private_key).to be_nil
        expect(domain.pending_dkim_identifier_string).to be_nil
        expect(domain.dkim_key.to_s).to eq pending_key
        expect(domain.pending_dkim_key).to be_nil
      end
    end
  end

  describe "#cancel_pending_dkim_key!" do
    let(:domain) { create(:domain, dkim_status: "OK") }

    before do
      domain.regenerate_dkim_key!
    end

    it "discards the pending key without changing the active key" do
      expect { domain.cancel_pending_dkim_key! }.to_not(change { domain.reload.dkim_private_key })
      expect(domain.pending_dkim_private_key).to be_nil
      expect(domain.pending_dkim_identifier_string).to be_nil
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

  describe "#pending_dkim_record" do
    context "when the domain has no pending DKIM key" do
      it "returns nil" do
        expect(domain.pending_dkim_record).to be_nil
      end
    end

    context "when the domain has a pending DKIM key" do
      let(:domain) { create(:domain, dkim_status: "OK") }

      before do
        domain.regenerate_dkim_key!
      end

      it "returns the DKIM record for the pending key" do
        expect(domain.pending_dkim_record).to match(/\Av=DKIM1; t=s; h=sha256; p=.*;\z/)
        expect(domain.pending_dkim_record).to_not eq domain.dkim_record
      end

      it "returns a record name using the pending identifier" do
        expect(domain.pending_dkim_record_name).to eq "#{Postal::Config.dns.dkim_identifier}-#{domain.pending_dkim_identifier_string}._domainkey"
      end
    end
  end

  describe "#check_dkim_record" do
    let(:domain) { create(:domain, dkim_status: "OK") }
    let(:resolver) { instance_double(DNSResolver) }

    before do
      allow(domain).to receive(:resolver).and_return(resolver)
    end

    context "when there is a pending DKIM key" do
      before do
        domain.regenerate_dkim_key!
      end

      context "when the pending record has been published" do
        it "activates and verifies the pending key from a single DNS response" do
          responses = [[domain.pending_dkim_record], []]
          allow(resolver).to receive(:txt).with("#{domain.pending_dkim_record_name}.#{domain.name}") { responses.shift }

          pending_key = domain.pending_dkim_private_key
          domain.check_dkim_record
          expect(domain.dkim_private_key).to eq pending_key
          expect(domain.pending_dkim_private_key).to be_nil
          expect(domain.dkim_status).to eq "OK"
          expect(domain.dkim_error).to be_nil
          expect(responses).to eq([[]])
        end
      end

      context "when multiple pending records have been published" do
        before do
          allow(resolver).to receive(:txt).with("#{domain.pending_dkim_record_name}.#{domain.name}").and_return([domain.pending_dkim_record, domain.pending_dkim_record])
          allow(resolver).to receive(:txt).with("#{domain.dkim_record_name}.#{domain.name}").and_return([domain.dkim_record])
        end

        it "keeps the current key active and retains the pending key" do
          original_key = domain.dkim_private_key
          domain.check_dkim_record
          expect(domain.dkim_private_key).to eq original_key
          expect(domain.pending_dkim_private_key).to_not be_nil
          expect(domain.dkim_status).to eq "OK"
        end
      end

      context "when the pending record has not been published" do
        before do
          allow(resolver).to receive(:txt).with("#{domain.pending_dkim_record_name}.#{domain.name}").and_return([])
          allow(resolver).to receive(:txt).with("#{domain.dkim_record_name}.#{domain.name}").and_return([domain.dkim_record])
        end

        it "keeps the current key active and retains the pending key" do
          original_key = domain.dkim_private_key
          domain.check_dkim_record
          expect(domain.dkim_private_key).to eq original_key
          expect(domain.pending_dkim_private_key).to_not be_nil
          expect(domain.dkim_status).to eq "OK"
        end
      end

      context "when the pending record does not match" do
        before do
          allow(resolver).to receive(:txt).with("#{domain.pending_dkim_record_name}.#{domain.name}").and_return(["v=DKIM1; t=s; h=sha256; p=something;"])
          allow(resolver).to receive(:txt).with("#{domain.dkim_record_name}.#{domain.name}").and_return([domain.dkim_record])
        end

        it "keeps the current key active and retains the pending key" do
          original_key = domain.dkim_private_key
          domain.check_dkim_record
          expect(domain.dkim_private_key).to eq original_key
          expect(domain.pending_dkim_private_key).to_not be_nil
          expect(domain.dkim_status).to eq "OK"
        end
      end
    end

    context "when there is no pending DKIM key" do
      context "when the record is published" do
        before do
          allow(resolver).to receive(:txt).with("#{domain.dkim_record_name}.#{domain.name}").and_return([domain.dkim_record])
        end

        it "marks the record as OK" do
          domain.check_dkim_record
          expect(domain.dkim_status).to eq "OK"
          expect(domain.dkim_error).to be_nil
        end
      end

      context "when the record is missing" do
        before do
          allow(resolver).to receive(:txt).with("#{domain.dkim_record_name}.#{domain.name}").and_return([])
        end

        it "marks the record as missing" do
          domain.check_dkim_record
          expect(domain.dkim_status).to eq "Missing"
        end
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
