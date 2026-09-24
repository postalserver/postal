# frozen_string_literal: true

# == Schema Information
#
# Table name: domains
#
#  id                             :integer          not null, primary key
#  dkim_error                     :string(255)
#  dkim_identifier_string         :string(255)
#  dkim_key_size                  :integer
#  dkim_private_key               :text(65535)
#  dkim_status                    :string(255)
#  dmarc_error                    :string(255)
#  dmarc_status                   :string(255)
#  dns_checked_at                 :datetime
#  incoming                       :boolean          default(TRUE)
#  mta_sts_error                  :string(255)
#  mta_sts_max_age                :integer          default(86400)
#  mta_sts_mode                   :string(255)      default("none")
#  mta_sts_policy_id              :string(255)
#  mta_sts_status                 :string(255)
#  mx_error                       :string(255)
#  mx_status                      :string(255)
#  name                           :string(255)
#  outgoing                       :boolean          default(TRUE)
#  owner_type                     :string(255)
#  pending_dkim_identifier_string :string(255)
#  pending_dkim_key_created_at    :datetime
#  pending_dkim_key_notified_at   :datetime
#  pending_dkim_private_key       :text(65535)
#  return_path_error              :string(255)
#  return_path_status             :string(255)
#  spf_error                      :string(255)
#  spf_status                     :string(255)
#  tls_rpt_error                  :string(255)
#  tls_rpt_status                 :string(255)
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

  describe "#dkim_key_size" do
    it "returns the configured size when the domain has no override" do
      expect(domain.dkim_key_size).to eq Postal::Config.dns.dkim_key_size
    end

    context "when the domain overrides the size" do
      let(:domain) { create(:domain, dkim_key_size: 1024) }

      it "returns the override" do
        expect(domain.dkim_key_size).to eq 1024
      end
    end
  end

  describe "#generate_dkim_key with an overridden size" do
    let(:domain) { build(:domain, dkim_key_size: 1024) }

    it "generates a key of the overridden size" do
      domain.generate_dkim_key
      expect(OpenSSL::PKey::RSA.new(domain.dkim_private_key).n.num_bits).to eq 1024
    end
  end

  describe "#dkim_record_chunks" do
    context "when the record fits in a single DNS string" do
      let(:domain) { create(:domain, dkim_key_size: 1024) }

      it "returns the record as a single chunk" do
        expect(domain.dkim_record_chunks).to eq [domain.dkim_record]
      end
    end

    context "when the record is longer than a single DNS string" do
      let(:domain) { create(:domain, dkim_key_size: 2048) }

      it "splits the record into several chunks" do
        expect(domain.dkim_record_chunks.size).to be > 1
      end

      it "keeps every chunk within the 255 character limit" do
        expect(domain.dkim_record_chunks.map(&:length).max).to be <= 255
      end

      it "joins back to the original record" do
        expect(domain.dkim_record_chunks.join).to eq domain.dkim_record
      end
    end
  end

  describe "#pending_dkim_record_chunks" do
    let(:domain) { create(:domain, dkim_key_size: 2048, dkim_status: "OK") }

    before do
      domain.regenerate_dkim_key!
    end

    it "splits the pending record" do
      expect(domain.pending_dkim_record_chunks.join).to eq domain.pending_dkim_record
    end
  end

  describe "#regenerate_dkim_key! timestamps" do
    let(:domain) { create(:domain, dkim_status: "OK") }

    it "records when the pending key was created" do
      expect { domain.regenerate_dkim_key! }.to change { domain.pending_dkim_key_created_at }.from(nil).to(kind_of(Time))
    end

    it "clears the timestamps when the key change is cancelled" do
      domain.regenerate_dkim_key!
      domain.cancel_pending_dkim_key!
      expect(domain.pending_dkim_key_created_at).to be_nil
      expect(domain.pending_dkim_key_notified_at).to be_nil
    end

    it "clears the reminder time when a new key change starts" do
      domain.regenerate_dkim_key!
      domain.update_column(:pending_dkim_key_notified_at, Time.now)
      domain.cancel_pending_dkim_key!
      domain.regenerate_dkim_key!
      expect(domain.pending_dkim_key_notified_at).to be_nil
    end
  end

  describe "#notify_pending_dkim_key!" do
    let(:organization) { create(:organization) }
    let(:server) { create(:server, organization: organization) }
    let(:domain) { create(:domain, owner: server, dkim_status: "OK") }

    before do
      allow(domain).to receive(:notification_organization).and_return(organization)
      allow(organization).to receive(:notification_addresses).and_return(["notifications@example.com"])
      domain.regenerate_dkim_key!
    end

    it "emails a reminder and records that it was sent" do
      expect(AppMailer).to receive(:domain_dkim_key_pending).with(domain).and_call_original
      expect { domain.notify_pending_dkim_key! }.to change { domain.pending_dkim_key_notified_at }.from(nil).to(kind_of(Time))
    end

    it "does not send a second reminder" do
      domain.notify_pending_dkim_key!
      expect(AppMailer).to_not receive(:domain_dkim_key_pending)
      expect(domain.notify_pending_dkim_key!).to be false
    end

    context "when there is no pending key" do
      let(:domain) { create(:domain, owner: server) }

      it "does nothing" do
        expect(AppMailer).to_not receive(:domain_dkim_key_pending)
        expect(domain.notify_pending_dkim_key!).to be false
      end
    end
  end

  describe ".dkim_key_change_notifiable" do
    let(:organization) { create(:organization) }
    let(:domain) { create(:domain, owner: organization, dkim_status: "OK") }

    before do
      domain.regenerate_dkim_key!
    end

    it "includes a key change which has been waiting longer than the period" do
      domain.update_column(:pending_dkim_key_created_at, 8.days.ago)
      expect(described_class.dkim_key_change_notifiable(7.days)).to include domain
    end

    it "excludes a key change which is still recent" do
      expect(described_class.dkim_key_change_notifiable(7.days)).to_not include domain
    end

    it "excludes domains which have already been reminded" do
      domain.update_columns(pending_dkim_key_created_at: 8.days.ago, pending_dkim_key_notified_at: Time.now)
      expect(described_class.dkim_key_change_notifiable(7.days)).to_not include domain
    end
  end

  describe "#dmarc_record" do
    it "returns a monitoring record" do
      expect(domain.dmarc_record).to eq "v=DMARC1; p=none; sp=none; adkim=s; aspf=r;"
    end

    it "does not include the retired pct tag" do
      expect(domain.dmarc_record).to_not include "pct"
    end

    context "when a report address is configured" do
      before do
        allow(Postal::Config.dns).to receive(:dmarc_report_address).and_return("dmarc@example.com")
      end

      it "includes the rua address" do
        expect(domain.dmarc_record).to include "rua=mailto:dmarc@example.com"
      end
    end

    context "when a failure report address is configured" do
      before do
        allow(Postal::Config.dns).to receive(:dmarc_failure_report_address).and_return("forensic@example.com")
      end

      it "includes the ruf address" do
        expect(domain.dmarc_record).to include "ruf=mailto:forensic@example.com"
      end
    end

    context "when the report address is already a mailto URI" do
      before do
        allow(Postal::Config.dns).to receive(:dmarc_report_address).and_return("mailto:dmarc@example.com")
      end

      it "does not repeat the scheme" do
        expect(domain.dmarc_record).to include "rua=mailto:dmarc@example.com"
        expect(domain.dmarc_record).to_not include "mailto:mailto:"
      end
    end
  end

  describe "#dmarc_record_name" do
    it "returns the DMARC record name" do
      expect(domain.dmarc_record_name).to eq "_dmarc"
    end
  end

  describe "#check_dmarc_record" do
    let(:resolver) { instance_double(DNSResolver) }

    before do
      allow(domain).to receive(:resolver).and_return(resolver)
    end

    context "when a valid record is published" do
      before do
        allow(resolver).to receive(:txt).with("_dmarc.#{domain.name}")
                                        .and_return(["v=DMARC1; p=reject; rua=mailto:dmarc@example.com"])
      end

      it "marks the record as OK" do
        domain.check_dmarc_record
        expect(domain.dmarc_status).to eq "OK"
        expect(domain.dmarc_error).to be_nil
      end
    end

    context "when no record is published" do
      before do
        allow(resolver).to receive(:txt).with("_dmarc.#{domain.name}").and_return([])
      end

      it "marks the record as missing" do
        domain.check_dmarc_record
        expect(domain.dmarc_status).to eq "Missing"
        expect(domain.dmarc_error).to be_present
      end
    end

    context "when several records are published" do
      before do
        allow(resolver).to receive(:txt).with("_dmarc.#{domain.name}")
                                        .and_return(["v=DMARC1; p=none", "v=DMARC1; p=reject"])
      end

      it "marks the record as invalid" do
        domain.check_dmarc_record
        expect(domain.dmarc_status).to eq "Invalid"
        expect(domain.dmarc_error).to include "only be one"
      end
    end

    context "when the record does not contain a policy" do
      before do
        allow(resolver).to receive(:txt).with("_dmarc.#{domain.name}")
                                        .and_return(["v=DMARC1; rua=mailto:dmarc@example.com"])
      end

      it "marks the record as invalid" do
        domain.check_dmarc_record
        expect(domain.dmarc_status).to eq "Invalid"
      end
    end
  end

  describe "#mta_sts_policy" do
    context "when the policy is disabled" do
      let(:domain) { create(:domain, mta_sts_mode: "none") }

      it "does not authorise any MX host" do
        expect(domain.mta_sts_policy).to eq "version: STSv1\nmode: none\nmax_age: 86400\n"
      end
    end

    context "when the policy is enabled" do
      let(:domain) { create(:domain, mta_sts_mode: "testing") }

      it "starts with the policy version and mode" do
        expect(domain.mta_sts_policy).to start_with "version: STSv1\nmode: testing\n"
      end

      it "lists every configured MX host" do
        Postal::Config.dns.mx_records.each do |mx|
          expect(domain.mta_sts_policy).to include "mx: #{mx}"
        end
      end

      it "ends with the maximum age" do
        expect(domain.mta_sts_policy).to end_with "max_age: #{domain.mta_sts_max_age}\n"
      end
    end
  end

  describe "#mta_sts_record" do
    let(:domain) { create(:domain, mta_sts_mode: "enforce") }

    it "advertises the policy id" do
      expect(domain.mta_sts_record).to eq "v=STSv1; id=#{domain.mta_sts_policy_id};"
    end
  end

  describe "#mta_sts_record_name" do
    it "returns the MTA-STS record name" do
      expect(domain.mta_sts_record_name).to eq "_mta-sts"
    end
  end

  describe "#mta_sts_enabled?" do
    it "is false while the policy is disabled" do
      expect(build(:domain, mta_sts_mode: "none").mta_sts_enabled?).to be false
    end

    it "is true while a policy is served" do
      expect(build(:domain, mta_sts_mode: "testing").mta_sts_enabled?).to be true
    end
  end

  describe "the MTA-STS policy identifier" do
    let(:domain) { create(:domain, mta_sts_mode: "testing") }

    it "is set when the domain is created" do
      expect(domain.mta_sts_policy_id).to be_present
    end

    it "is within the length the specification allows" do
      expect(domain.mta_sts_policy_id).to match(/\A[A-Za-z0-9]{1,32}\z/)
    end

    it "changes when the policy changes" do
      original = domain.mta_sts_policy_id
      domain.update!(mta_sts_mode: "enforce")
      expect(domain.mta_sts_policy_id).to_not eq original
    end

    it "stays the same when the policy is unchanged" do
      original = domain.mta_sts_policy_id
      domain.update!(name: "unrelated#{rand(1_000_000)}.com")
      expect(domain.mta_sts_policy_id).to eq original
    end
  end

  describe "MTA-STS validations" do
    it "rejects an unknown mode" do
      expect(build(:domain, mta_sts_mode: "sometimes")).to_not be_valid
    end

    it "rejects a maximum age beyond the allowed limit" do
      expect(build(:domain, mta_sts_max_age: Domain::MTA_STS_MAX_AGE_LIMIT + 1)).to_not be_valid
    end

    it "accepts the largest allowed maximum age" do
      expect(build(:domain, mta_sts_max_age: Domain::MTA_STS_MAX_AGE_LIMIT)).to be_valid
    end
  end

  describe "#check_mta_sts_record" do
    let(:resolver) { instance_double(DNSResolver) }

    before do
      allow(domain).to receive(:resolver).and_return(resolver)
    end

    context "when no policy is published" do
      let(:domain) { create(:domain, mta_sts_mode: "none") }

      it "reports nothing" do
        domain.update_column(:mta_sts_status, "OK")
        domain.check_mta_sts_record
        expect(domain.mta_sts_status).to be_nil
      end
    end

    context "when the policy is enabled" do
      let(:domain) { create(:domain, mta_sts_mode: "testing") }

      context "when the record matches the policy" do
        before do
          allow(resolver).to receive(:txt).with("_mta-sts.#{domain.name}").and_return([domain.mta_sts_record])
        end

        it "marks the record as OK" do
          domain.check_mta_sts_record
          expect(domain.mta_sts_status).to eq "OK"
          expect(domain.mta_sts_error).to be_nil
        end
      end

      context "when the record is missing" do
        before do
          allow(resolver).to receive(:txt).with("_mta-sts.#{domain.name}").and_return([])
        end

        it "marks the record as missing" do
          domain.check_mta_sts_record
          expect(domain.mta_sts_status).to eq "Missing"
        end
      end

      context "when the record advertises a stale policy id" do
        before do
          allow(resolver).to receive(:txt).with("_mta-sts.#{domain.name}")
                                          .and_return(["v=STSv1; id=STALEPOLICYID;"])
        end

        it "marks the record as invalid" do
          domain.check_mta_sts_record
          expect(domain.mta_sts_status).to eq "Invalid"
          expect(domain.mta_sts_error).to include "policy id"
        end
      end

      context "when more than one record is published" do
        before do
          allow(resolver).to receive(:txt).with("_mta-sts.#{domain.name}")
                                          .and_return([domain.mta_sts_record, domain.mta_sts_record])
        end

        it "marks the record as invalid" do
          domain.check_mta_sts_record
          expect(domain.mta_sts_status).to eq "Invalid"
          expect(domain.mta_sts_error).to include "only be one"
        end
      end
    end
  end

  describe "#mta_sts_hostname" do
    it "is the mta-sts host of the domain" do
      expect(domain.mta_sts_hostname).to eq "mta-sts.#{domain.name}"
    end
  end

  describe "#mta_sts_certificate_required?" do
    it "is false while no policy is served" do
      expect(build(:domain, mta_sts_mode: "none").mta_sts_certificate_required?).to be false
    end

    it "is true when no certificate has been obtained" do
      expect(build(:domain, mta_sts_mode: "testing").mta_sts_certificate_required?).to be true
    end

    it "is true when the certificate is close to expiring" do
      domain = build(:domain, mta_sts_mode: "testing", mta_sts_certificate_expires_at: 10.days.from_now)
      expect(domain.mta_sts_certificate_required?).to be true
    end

    it "is false while the certificate is valid for the foreseeable future" do
      domain = build(:domain, mta_sts_mode: "testing", mta_sts_certificate_expires_at: 60.days.from_now)
      expect(domain.mta_sts_certificate_required?).to be false
    end
  end

  describe "#issue_mta_sts_certificate!" do
    let(:key) { OpenSSL::PKey::RSA.new(2048) }
    let(:certificate) do
      certificate = OpenSSL::X509::Certificate.new
      certificate.version = 2
      certificate.serial = 1
      certificate.subject = OpenSSL::X509::Name.parse("/CN=mta-sts.example.com")
      certificate.issuer = certificate.subject
      certificate.public_key = key.public_key
      certificate.not_before = Time.now
      certificate.not_after = Time.now + (90 * 24 * 60 * 60)
      certificate.sign(key, OpenSSL::Digest.new("SHA256"))
      certificate
    end
    let(:directory) { Dir.mktmpdir("mta-sts-certs") }
    let(:domain) { create(:domain, mta_sts_mode: "testing") }

    before do
      allow(Postal::Config.mta_sts).to receive(:certificate_directory).and_return(directory)
      allow(Postal::ACME).to receive(:issue).with(domain.mta_sts_hostname)
                                            .and_return(certificate: certificate.to_pem, key: key.to_pem)
    end

    after do
      FileUtils.remove_entry(directory) if File.directory?(directory)
    end

    it "requests a certificate for the policy host" do
      domain.issue_mta_sts_certificate!
      expect(Postal::ACME).to have_received(:issue).with(domain.mta_sts_hostname)
    end

    it "stores the certificate and the key it was issued for" do
      domain.issue_mta_sts_certificate!
      expect(File.read(domain.mta_sts_certificate_path)).to eq certificate.to_pem
      expect(File.read(domain.mta_sts_private_key_path)).to eq key.to_pem
    end

    it "does not leave the private key readable by anybody else" do
      domain.issue_mta_sts_certificate!
      expect(File.stat(domain.mta_sts_private_key_path).mode & 0o777).to eq 0o600
    end

    it "records when the certificate was obtained and when it expires" do
      domain.issue_mta_sts_certificate!
      domain.reload
      expect(domain.mta_sts_certificate_status).to eq "OK"
      expect(domain.mta_sts_certificate_expires_at).to be_within(1.second).of(certificate.not_after)
      expect(domain.mta_sts_certificate_obtained_at).to be_a Time
    end

    context "when the certificate cannot be obtained" do
      before do
        allow(Postal::ACME).to receive(:issue).and_raise(Postal::ACME::Error, "rejected")
      end

      it "records the error and raises" do
        expect { domain.issue_mta_sts_certificate! }.to raise_error(Postal::ACME::Error)
        domain.reload
        expect(domain.mta_sts_certificate_status).to eq "Error"
        expect(domain.mta_sts_certificate_error).to eq "rejected"
      end

      it "does not store a certificate" do
        expect { domain.issue_mta_sts_certificate! }.to raise_error(Postal::ACME::Error)
        expect(File.exist?(domain.mta_sts_certificate_path)).to be false
      end
    end
  end

  describe "#tls_rpt_record" do
    context "when no destination is configured" do
      it "returns nothing" do
        expect(domain.tls_rpt_record).to be_nil
      end
    end

    context "when a mailbox is configured" do
      before do
        allow(Postal::Config.dns).to receive(:tls_rpt_address).and_return("tlsrpt@example.com")
      end

      it "uses the mailto scheme" do
        expect(domain.tls_rpt_record).to eq "v=TLSRPTv1; rua=mailto:tlsrpt@example.com;"
      end
    end

    context "when an endpoint is configured" do
      before do
        allow(Postal::Config.dns).to receive(:tls_rpt_address).and_return("https://reports.example.com/tls")
      end

      it "uses the destination as it is" do
        expect(domain.tls_rpt_record).to eq "v=TLSRPTv1; rua=https://reports.example.com/tls;"
      end
    end

    context "when several destinations are configured" do
      before do
        allow(Postal::Config.dns).to receive(:tls_rpt_address)
          .and_return("tlsrpt@example.com, https://reports.example.com/tls")
      end

      it "gives each of them a scheme and keeps them separate" do
        expect(domain.tls_rpt_record).to eq "v=TLSRPTv1; rua=mailto:tlsrpt@example.com,https://reports.example.com/tls;"
      end
    end
  end

  describe "#tls_rpt_record_name" do
    it "returns the TLS-RPT record name" do
      expect(domain.tls_rpt_record_name).to eq "_smtp._tls"
    end
  end

  describe "#check_tls_rpt_record" do
    let(:resolver) { instance_double(DNSResolver) }

    before do
      allow(domain).to receive(:resolver).and_return(resolver)
    end

    context "when no destination is configured" do
      it "reports nothing" do
        domain.tls_rpt_status = "OK"
        domain.check_tls_rpt_record
        expect(domain.tls_rpt_status).to be_nil
      end
    end

    context "when a destination is configured" do
      before do
        allow(Postal::Config.dns).to receive(:tls_rpt_address).and_return("tlsrpt@example.com")
      end

      it "marks a single usable record as OK" do
        allow(resolver).to receive(:txt).with("_smtp._tls.#{domain.name}").and_return([domain.tls_rpt_record])
        domain.check_tls_rpt_record
        expect(domain.tls_rpt_status).to eq "OK"
      end

      it "marks a missing record as missing" do
        allow(resolver).to receive(:txt).with("_smtp._tls.#{domain.name}").and_return([])
        domain.check_tls_rpt_record
        expect(domain.tls_rpt_status).to eq "Missing"
      end

      it "marks several records as invalid" do
        records = [domain.tls_rpt_record, domain.tls_rpt_record]
        allow(resolver).to receive(:txt).with("_smtp._tls.#{domain.name}").and_return(records)
        domain.check_tls_rpt_record
        expect(domain.tls_rpt_status).to eq "Invalid"
      end

      it "marks a record with no destination as invalid" do
        allow(resolver).to receive(:txt).with("_smtp._tls.#{domain.name}").and_return(["v=TLSRPTv1;"])
        domain.check_tls_rpt_record
        expect(domain.tls_rpt_status).to eq "Invalid"
      end
    end
  end
end
