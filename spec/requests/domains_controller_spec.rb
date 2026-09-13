# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DomainsController", type: :request do
  let(:user) { create(:user, admin: true) }
  let(:organization) { create(:organization, owner: user) }
  let(:server) { create(:server, organization: organization) }

  before do
    post "/login", params: { email_address: user.email_address, password: "passw0rd" }
  end

  describe "POST /org/:org/servers/:server/domains/:domain/regenerate_dkim" do
    context "when the domain's DKIM record is verified" do
      let(:domain) { create(:domain, owner: server, dkim_status: "OK") }

      it "generates a pending DKIM key without changing the active key" do
        original_key = domain.dkim_private_key
        post "/org/#{organization.permalink}/servers/#{server.permalink}/domains/#{domain.uuid}/regenerate_dkim"
        expect(response).to redirect_to(setup_organization_server_domain_path(organization, server, domain))
        expect(flash[:notice]).to include("Keep the old DNS record published afterward")
        expect(flash[:notice]).to include("queued, held, or available for redelivery")
        expect(flash[:notice]).to_not include("you can remove the old record")
        domain.reload
        expect(domain.dkim_private_key).to eq original_key
        expect(domain.pending_dkim_private_key).to_not be_nil
      end
    end

    context "when the domain's DKIM record is not verified" do
      let(:domain) { create(:domain, owner: server, dkim_status: "Missing") }

      it "replaces the active key immediately" do
        original_key = domain.dkim_private_key
        post "/org/#{organization.permalink}/servers/#{server.permalink}/domains/#{domain.uuid}/regenerate_dkim"
        expect(response).to redirect_to(setup_organization_server_domain_path(organization, server, domain))
        domain.reload
        expect(domain.dkim_private_key).to_not eq original_key
        expect(domain.pending_dkim_private_key).to be_nil
        expect(domain.dkim_status).to be_nil
      end
    end

    context "when a key change is already in progress" do
      let(:domain) { create(:domain, owner: server, dkim_status: "OK") }

      before do
        domain.regenerate_dkim_key!
      end

      it "refuses and leaves the pending key untouched" do
        existing_pending_key = domain.pending_dkim_private_key
        existing_pending_identifier = domain.pending_dkim_identifier_string
        post "/org/#{organization.permalink}/servers/#{server.permalink}/domains/#{domain.uuid}/regenerate_dkim"
        expect(response).to redirect_to(setup_organization_server_domain_path(organization, server, domain))
        expect(flash[:alert]).to include("already in progress")
        domain.reload
        expect(domain.pending_dkim_private_key).to eq existing_pending_key
        expect(domain.pending_dkim_identifier_string).to eq existing_pending_identifier
      end

      it "does not change the active key" do
        expect do
          post "/org/#{organization.permalink}/servers/#{server.permalink}/domains/#{domain.uuid}/regenerate_dkim"
        end.to_not(change { domain.reload.dkim_private_key })
      end
    end
  end

  describe "POST /org/:org/domains/:domain/regenerate_dkim" do
    let(:domain) { create(:domain, owner: organization, dkim_status: "OK") }

    it "generates a pending DKIM key for an organization-owned domain" do
      post "/org/#{organization.permalink}/domains/#{domain.uuid}/regenerate_dkim"
      expect(response).to redirect_to(setup_organization_domain_path(organization, domain))
      expect(domain.reload.pending_dkim_private_key).to_not be_nil
    end
  end

  describe "POST /org/:org/servers/:server/domains/:domain/check with a pending DKIM key" do
    let(:domain) { create(:domain, owner: server, dkim_status: "OK") }
    let(:resolver) { instance_double(DNSResolver) }

    before do
      domain.regenerate_dkim_key!
      allow(DNSResolver).to receive(:for_domain).and_return(resolver)
      allow(resolver).to receive(:txt).with(domain.name).and_return([domain.spf_record])
      allow(resolver).to receive(:mx).with(domain.name).and_return([])
      allow(resolver).to receive(:cname).and_return([])
    end

    context "when the pending DKIM record has been published" do
      before do
        allow(resolver).to receive(:txt).with("#{domain.pending_dkim_record_name}.#{domain.name}").and_return([domain.pending_dkim_record])
      end

      it "activates the pending key and tells the user to retain the old record" do
        old_record_name = domain.dkim_record_name
        new_key = domain.pending_dkim_private_key
        post "/org/#{organization.permalink}/servers/#{server.permalink}/domains/#{domain.uuid}/check"
        expect(response).to redirect_to(setup_organization_server_domain_path(organization, server, domain))
        expect(flash[:notice]).to include("new DKIM key is now active")
        expect(flash[:notice]).to include(old_record_name)
        expect(flash[:notice]).to include("queued, held, or available for redelivery")
        expect(flash[:notice]).to_not include("can remove")
        domain.reload
        expect(domain.dkim_private_key).to eq new_key
        expect(domain.pending_dkim_private_key).to be_nil
        expect(domain.dkim_status).to eq "OK"
      end
    end

    context "when the pending DKIM record has not been published" do
      before do
        allow(resolver).to receive(:txt).with("#{domain.pending_dkim_record_name}.#{domain.name}").and_return([])
        allow(resolver).to receive(:txt).with("#{domain.dkim_record_name}.#{domain.name}").and_return([domain.dkim_record])
      end

      it "keeps the current key active and tells the user the new record wasn't verified" do
        post "/org/#{organization.permalink}/servers/#{server.permalink}/domains/#{domain.uuid}/check"
        expect(response).to redirect_to(setup_organization_server_domain_path(organization, server, domain))
        expect(flash[:alert]).to include("couldn't verify the record for your new DKIM key")
        domain.reload
        expect(domain.pending_dkim_private_key).to_not be_nil
        expect(domain.dkim_status).to eq "OK"
      end
    end
  end

  describe "POST /org/:org/servers/:server/domains/:domain/cancel_dkim_regeneration" do
    let(:domain) { create(:domain, owner: server, dkim_status: "OK") }

    before do
      domain.regenerate_dkim_key!
    end

    it "discards the pending DKIM key" do
      post "/org/#{organization.permalink}/servers/#{server.permalink}/domains/#{domain.uuid}/cancel_dkim_regeneration"
      expect(response).to redirect_to(setup_organization_server_domain_path(organization, server, domain))
      expect(domain.reload.pending_dkim_private_key).to be_nil
    end
  end
end
