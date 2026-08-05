# frozen_string_literal: true

# == Schema Information
#
# Table name: servers
#
#  id                                 :integer          not null, primary key
#  allow_sender                       :boolean          default(FALSE)
#  deleted_at                         :datetime
#  domains_not_to_click_track         :text(65535)
#  log_smtp_data                      :boolean          default(FALSE)
#  message_retention_days             :integer
#  mode                               :string(255)
#  name                               :string(255)
#  outbound_spam_threshold            :decimal(8, 2)
#  permalink                          :string(255)
#  postmaster_address                 :string(255)
#  privacy_mode                       :boolean          default(FALSE)
#  raw_message_retention_days         :integer
#  raw_message_retention_size         :integer
#  send_limit                         :integer
#  send_limit_approaching_at          :datetime
#  send_limit_approaching_notified_at :datetime
#  send_limit_exceeded_at             :datetime
#  send_limit_exceeded_notified_at    :datetime
#  spam_failure_threshold             :decimal(8, 2)
#  spam_threshold                     :decimal(8, 2)
#  suspended_at                       :datetime
#  suspension_reason                  :string(255)
#  token                              :string(255)
#  uuid                               :string(255)
#  created_at                         :datetime
#  updated_at                         :datetime
#  ip_pool_id                         :integer
#  organization_id                    :integer
#
# Indexes
#
#  index_servers_on_organization_id  (organization_id)
#  index_servers_on_permalink        (permalink)
#  index_servers_on_token            (token)
#  index_servers_on_uuid             (uuid)
#
require "rails_helper"

describe Server do
  subject(:server) { build(:server) }

  describe "relationships" do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:ip_pool).optional }
    it { is_expected.to have_many(:domains) }
    it { is_expected.to have_many(:credentials) }
    it { is_expected.to have_many(:smtp_endpoints) }
    it { is_expected.to have_many(:http_endpoints) }
    it { is_expected.to have_many(:address_endpoints) }
    it { is_expected.to have_many(:routes) }
    it { is_expected.to have_many(:queued_messages) }
    it { is_expected.to have_many(:webhooks) }
    it { is_expected.to have_many(:webhook_requests) }
    it { is_expected.to have_many(:track_domains) }
    it { is_expected.to have_many(:ip_pool_rules) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:organization_id).case_insensitive }
    it { is_expected.to validate_inclusion_of(:mode).in_array(Server::MODES) }
    it { is_expected.to validate_uniqueness_of(:permalink).scoped_to(:organization_id).case_insensitive }
    it { is_expected.to validate_exclusion_of(:permalink).in_array(Server::RESERVED_PERMALINKS) }
    it { is_expected.to allow_value("hello").for(:permalink) }
    it { is_expected.to allow_value("hello-world").for(:permalink) }
    it { is_expected.to allow_value("hello1234").for(:permalink) }
    it { is_expected.not_to allow_value("LARGE").for(:permalink) }
    it { is_expected.not_to allow_value(" lots of spaces ").for(:permalink) }
    it { is_expected.not_to allow_value("hello+").for(:permalink) }
    it { is_expected.not_to allow_value("!!!").for(:permalink) }
    it { is_expected.not_to allow_value("[hello]").for(:permalink) }

    describe "ip pool validation" do
      let(:org) { create(:organization) }
      let(:ip_pool) { create(:ip_pool) }
      let(:server) { build(:server, organization: org, ip_pool: ip_pool) }

      context "when the IP pool does not belong to the same organization" do
        it "adds an error" do
          expect(server.save).to be false
          expect(server.errors[:ip_pool_id]).to include(/must belong to the organization/)
        end
      end

      context "whent he IP pool does belong to the the same organization" do
        before do
          org.ip_pools << ip_pool
        end

        it "does not add an error" do
          expect(server.save).to be true
        end
      end
    end
  end

  describe "creation" do
    let(:server) { build(:server) }

    it "generates a uuid" do
      expect { server.save }.to change { server.uuid }.from(nil).to(/[a-f0-9-]{36}/)
    end

    it "generates a token" do
      expect { server.save }.to change { server.token }.from(nil).to(/[a-z0-9]{6}/)
    end

    it "provisions a database" do
      expect(server.message_db.provisioner).to receive(:provision).once
      server.provision_database = true
      server.save
    end
  end

  describe "deletion" do
    let(:server) { create(:server) }

    it "removes the database" do
      expect(server.message_db.provisioner).to receive(:drop).once
      server.provision_database = true
      server.destroy
    end
  end

  describe "#status" do
    context "when the server is suspended" do
      let(:server) { build(:server, :suspended) }

      it "returns Suspended" do
        expect(server.status).to eq("Suspended")
      end
    end

    context "when the server is not suspended" do
      it "returns the mode" do
        expect(server.status).to eq "Live"
      end
    end
  end

  describe "#full_permalink" do
    it "returns the org and server permalinks concatenated" do
      expect(server.full_permalink).to eq "#{server.organization.permalink}/#{server.permalink}"
    end
  end

  describe "#suspended?" do
    context "when the server is suspended" do
      let(:server) { build(:server, :suspended) }

      it "returns true" do
        expect(server).to be_suspended
      end
    end

    context "when the server is not suspended" do
      it "returns false" do
        expect(server).not_to be_suspended
      end
    end
  end

  describe "#actual_suspension_reason" do
    context "when the server is not suspended" do
      it "returns nil" do
        expect(server.actual_suspension_reason).to be_nil
      end
    end

    context "when the server is not suspended by the organization is" do
      let(:org) { build(:organization, :suspended, suspension_reason: "org test") }
      let(:server) { build(:server, organization: org) }

      it "returns the organization suspension reason" do
        expect(server.actual_suspension_reason).to eq "org test"
      end
    end

    context "when the server is suspended" do
      let(:server) { build(:server, :suspended, suspension_reason: "server test") }

      it "returns the suspension reason" do
        expect(server.actual_suspension_reason).to eq "server test"
      end
    end
  end

  describe "#to_param" do
    it "returns the permalink" do
      expect(server.to_param).to eq server.permalink
    end
  end

  describe "#message_db" do
    it "returns a message DB instance" do
      expect(server.message_db).to be_a Postal::MessageDB::Database
      expect(server.message_db).to have_attributes(server_id: server.id, organization_id: server.organization.id)
    end

    it "caches the value" do
      call1 = server.message_db
      call2 = server.message_db
      expect(call1.object_id).to eq(call2.object_id)
    end
  end

  describe "#message" do
    it "delegates to the message db" do
      expect(server.message_db).to receive(:message).with(1)
      server.message(1)
    end
  end

  describe "#message_rate" do
    it "returns the live stats for the last hour per minute" do
      allow(server.message_db.live_stats).to receive(:total).and_return(600)
      expect(server.message_rate).to eq 10
      expect(server.message_db.live_stats).to have_received(:total).with(60, types: [:incoming, :outgoing])
    end
  end

  describe "#held_messages" do
    it "returns the number of held messages" do
      expect(server.message_db).to receive(:messages).with(count: true, where: { held: true }).and_return(50)
      expect(server.held_messages).to eq 50
    end
  end

  describe "#throughput_stats" do
    before do
      allow(server.message_db.live_stats).to receive(:total).with(60, types: [:incoming]).and_return(50)
      allow(server.message_db.live_stats).to receive(:total).with(60, types: [:outgoing]).and_return(100)
    end

    context "when the server has a sent limit" do
      let(:server) { build(:server, send_limit: 500) }

      it "returns the stats with an outgoing usage percentage" do
        expect(server.throughput_stats).to eq({
          incoming: 50,
          outgoing: 100,
          outgoing_usage: 20.0
        })
      end
    end

    context "when the server does not have a sent limit" do
      it "returns the stats with no outgoing usage percentage" do
        expect(server.throughput_stats).to eq({
          incoming: 50,
          outgoing: 100,
          outgoing_usage: 0
        })
      end
    end
  end

  describe "#bounce_rate" do
    context "when there are no outgoing emails" do
      it "returns zero" do
        expect(server.bounce_rate).to eq 0
      end
    end

    context "when there are outgoing emails with some bounces" do
      it "returns the rate" do
        allow(server.message_db.statistics).to receive(:get).with(:daily, [:outgoing, :bounces], kind_of(Time), 30)
                                                            .and_return({
                                                                          10.minutes.ago => { outgoing: 150, bounces: 50 },
                                                                          5.minutes.ago => { outgoing: 350, bounces: 30 },
                                                                          1.minutes.ago => { outgoing: 500, bounces: 20 }
                                                                        })
        expect(server.bounce_rate).to eq 10.0
      end
    end
  end

  describe "#domain_stats" do
    it "returns stats about the domains associated with the server" do
      create(:domain, owner: server) # verified, bad dns
      create(:domain, :unverified, owner: server) # unverified
      create(:domain, :dns_all_ok, owner: server) # verified good dns

      expect(server.domain_stats).to eq [3, 1, 1]
    end
  end

  describe "#webhook_hash" do
    it "returns a hash to represent the server" do
      expect(server.webhook_hash).to eq({
        uuid: server.uuid,
        name: server.name,
        permalink: server.permalink,
        organization: server.organization.permalink
      })
    end
  end

  describe "#send_volume" do
    it "returns the number of outgoing messages sent in the last hour" do
      allow(server.message_db.live_stats).to receive(:total).with(60, types: [:outgoing]).and_return(50)
      expect(server.send_volume).to eq 50
    end
  end

  describe "#send_limit_approaching?" do
    context "when the server has no send limit" do
      it "returns false" do
        expect(server.send_limit_approaching?).to be false
      end
    end

    context "when the server has a send limit" do
      let(:server) { build(:server, send_limit: 1000) }

      context "when the server's send volume is less 90% of the limit" do
        it "return false" do
          allow(server).to receive(:send_volume).and_return(800)
          expect(server.send_limit_approaching?).to be false
        end
      end

      context "when the server's send volume is more than 90% of the limit" do
        it "returns true" do
          allow(server).to receive(:send_volume).and_return(901)
          expect(server.send_limit_approaching?).to be true
        end
      end
    end
  end

  describe "#send_limit_warning" do
    let(:server) { create(:server, send_limit: 1000) }

    before do
      allow(server).to receive(:send_volume).and_return(500)
    end

    context "when given the :approaching argument" do
      it "sends an email to the org notification addresses" do
        server.organization.users << create(:user)

        server.send_limit_warning(:approaching)
        delivery = ActionMailer::Base.deliveries.last
        expect(delivery).to have_attributes(subject: /mail server is approaching its send limit/i)
      end

      it "sets the notification time" do
        expect { server.send_limit_warning(:approaching) }.to change { server.send_limit_approaching_notified_at }
          .from(nil).to(kind_of(Time))
      end

      it "triggers a webhook" do
        expect(WebhookRequest).to receive(:trigger).with(server, "SendLimitApproaching", server: server.webhook_hash, volume: 500, limit: 1000)
        server.send_limit_warning(:approaching)
      end
    end

    context "when given the :exceeded argument" do
      it "sends an email to the org notification addresses" do
        server.organization.users << create(:user)

        server.send_limit_warning(:exceeded)
        delivery = ActionMailer::Base.deliveries.last
        expect(delivery).to have_attributes(subject: /mail server has exceeded its send limit/i)
      end

      it "sets the notification time" do
        expect { server.send_limit_warning(:exceeded) }.to change { server.send_limit_exceeded_notified_at }
          .from(nil).to(kind_of(Time))
      end

      it "triggers a webhook" do
        expect(WebhookRequest).to receive(:trigger).with(server, "SendLimitExceeded", server: server.webhook_hash, volume: 500, limit: 1000)
        server.send_limit_warning(:exceeded)
      end
    end
  end

  describe "#queue_size" do
    it "returns the number of queued messages that are ready" do
      create(:queued_message, server: server, retry_after: nil)
      create(:queued_message, server: server, retry_after: 1.minute.ago)
      expect(server.queue_size).to eq 2
    end
  end

  describe "#authenticated_domain_for_address" do
    context "when the address given is blank" do
      it "returns nil" do
        expect(server.authenticated_domain_for_address("")).to be nil
        expect(server.authenticated_domain_for_address(nil)).to be nil
      end
    end

    context "when the address given does not have a username & domain component" do
      it "returns nil" do
        expect(server.authenticated_domain_for_address("blah")).to be nil
      end
    end

    context "when there is a verified org-level domain matching the address provided" do
      it "returns that domain" do
        server = create(:server)
        domain = create(:domain, owner: server.organization, name: "mangos.io")
        expect(server.authenticated_domain_for_address("hello@mangos.io")).to eq domain
      end
    end

    context "when there is a verified server-level domain matching the address provided" do
      it "returns that domain" do
        domain = create(:domain, owner: server, name: "oranges.io")
        expect(server.authenticated_domain_for_address("hello@oranges.io")).to eq domain
      end
    end

    context "when there is a verified server-level domain matching the address and a use_for_any" do
      it "returns the matching domain" do
        domain = create(:domain, owner: server, name: "oranges.io")
        create(:domain, owner: server, name: "pears.com", use_for_any: true)
        expect(server.authenticated_domain_for_address("hello@oranges.io")).to eq domain
      end
    end

    context "when there is a verified server-level and org-level domain with the same name" do
      it "returns the server-level domain" do
        domain = create(:domain, owner: server, name: "lemons.com")
        create(:domain, owner: server.organization, name: "lemons.com")
        expect(server.authenticated_domain_for_address("hello@lemons.com")).to eq domain
      end
    end

    context "when there is a verified server-level domain with the 'use_for_any' boolean set with a different name" do
      it "returns that domain" do
        create(:domain, owner: server, name: "pears.com")
        domain = create(:domain, owner: server, name: "apples.io", use_for_any: true)
        expect(server.authenticated_domain_for_address("hello@bananas.com")).to eq domain
      end
    end

    context "when there is no suitable domain" do
      it "returns nil" do
        server = create(:server)
        create(:domain, owner: server, name: "pears.com")
        create(:domain, owner: server.organization, name: "pineapples.com")
        expect(server.authenticated_domain_for_address("hello@bananas.com")).to be nil
      end
    end
  end

  describe "#find_authenticated_domain_from_headers" do
    context "when none of the from addresses have a valid domain" do
      it "returns nil" do
        expect(server.find_authenticated_domain_from_headers("from" => "test@lemons.com")).to be nil
      end
    end

    context "when the from addresses has a valid domain" do
      it "returns the domain" do
        domain = create(:domain, owner: server)
        expect(server.find_authenticated_domain_from_headers("from" => "hello@#{domain.name}")).to eq domain
      end
    end

    context "when there are multiple from addresses" do
      context "when none of them match a domain" do
        it "returns nil" do
          expect(server.find_authenticated_domain_from_headers("from" => ["hello@lemons.com", "hello@apples.com"])).to be nil
        end
      end

      context "when some but not all match" do
        it "returns nil" do
          domain = create(:domain, owner: server)
          expect(server.find_authenticated_domain_from_headers("from" => ["hello@#{domain.name}", "hello@lemons.com"])).to be nil
        end
      end

      context "when all match" do
        it "returns the first domain that matched" do
          domain1 = create(:domain, owner: server)
          domain2 = create(:domain, owner: server)
          expect(server.find_authenticated_domain_from_headers("from" => ["hello@#{domain1.name}", "hello@#{domain2.name}"])).to eq domain1
        end
      end
    end

    context "when the server is not allowed to use the sender header" do
      context "when the sender header has a valid address" do
        it "does not return the domain" do
          domain = create(:domain, owner: server)
          result = server.find_authenticated_domain_from_headers(
            "from" => "hello@lemons.com",
            "sender" => "hello@#{domain.name}"
          )
          expect(result).to be nil
        end
      end
    end

    context "when the server is allowed to use the sender header" do
      let(:server) { build(:server, allow_sender: true) }

      context "when none of the from addresses match but sender domains do" do
        it "returns the domain that does match" do
          domain = create(:domain, owner: server)
          result = server.find_authenticated_domain_from_headers(
            "from" => "hello@lemons.com",
            "sender" => "hello@#{domain.name}"
          )
          expect(result).to eq domain
        end
      end
    end
  end

  describe "#suspend" do
    let(:server) { create(:server) }

    it "sets the suspension time" do
      expect { server.suspend("some reason") }.to change { server.reload.suspended_at }.from(nil).to(kind_of(Time))
    end

    it "sets the suspension reason" do
      expect { server.suspend("some reason") }.to change { server.reload.suspension_reason }.from(nil).to("some reason")
    end

    context "when there are no notification addresses" do
      it "does not send an email" do
        server.suspend("some reason")
        expect(ActionMailer::Base.deliveries).to be_empty
      end
    end

    context "when there are notification addresses" do
      before do
        server.organization.users << create(:user)
      end

      it "sends an email" do
        server.suspend("some reason")
        delivery = ActionMailer::Base.deliveries.last
        expect(delivery).to have_attributes(subject: /server has been suspended/i)
      end
    end
  end

  describe "#unsuspend" do
    let(:server) { create(:server, :suspended) }

    it "removes the suspension time" do
      expect { server.unsuspend }.to change { server.reload.suspended_at }.to(nil)
    end

    it "removes the suspension reason" do
      expect { server.unsuspend }.to change { server.reload.suspension_reason }.to(nil)
    end
  end

  describe "#ip_pool_for_message" do
    context "when the message is not outgoing" do
      let(:message) { MessageFactory.incoming(server) }

      it "returns nil" do
        expect(server.ip_pool_for_message(message)).to be nil
      end
    end

    context "when a server rule matches the message" do
      let(:domain) { create(:domain, owner: server) }
      let(:ip_pool) { create(:ip_pool, organizations: [server.organization]) }
      let(:message) do
        MessageFactory.outgoing(server, domain: domain) do |msg|
          msg.rcpt_to = "hello@google.com"
        end
      end

      before do
        create(:ip_pool_rule, ip_pool: ip_pool, owner: server, from_text: nil, to_text: "google.com")
      end

      it "returns the pool" do
        expect(server.ip_pool_for_message(message)).to eq ip_pool
      end
    end

    context "when an org rule matches the message" do
      let(:domain) { create(:domain, owner: server) }
      let(:ip_pool) { create(:ip_pool, organizations: [server.organization]) }
      let(:message) do
        MessageFactory.outgoing(server, domain: domain) do |msg|
          msg.rcpt_to = "hello@google.com"
        end
      end

      before do
        create(:ip_pool_rule, ip_pool: ip_pool, owner: server.organization, from_text: nil, to_text: "google.com")
      end

      it "returns the pool" do
        expect(server.ip_pool_for_message(message)).to eq ip_pool
      end
    end

    context "when the server has no default pool and no rules match the message" do
      let(:domain) { create(:domain, owner: server) }
      let(:message) { MessageFactory.outgoing(server, domain: domain) }

      it "returns nil" do
        expect(server.ip_pool_for_message(message)).to be nil
      end
    end

    context "when the server has a default pool and no rules match the message" do
      let(:organization) { create(:organization) }
      let(:ip_pool) { create(:ip_pool, organizations: [organization]) }
      let(:server) { create(:server, organization: organization, ip_pool: ip_pool) }
      let(:domain) { create(:domain, owner: server) }
      let(:message) { MessageFactory.outgoing(server, domain: domain) }

      it "returns the server's default pool" do
        expect(server.ip_pool_for_message(message)).to eq ip_pool
      end
    end
  end

  describe ".[]" do
    context "when provided with an integer" do
      it "returns the server with that ID" do
        server = create(:server)
        expect(described_class[server.id]).to eq server
      end

      it "returns nil if no server exists with the ID" do
        expect(described_class[1234]).to be nil
      end
    end

    context "when provided with a string" do
      it "returns the server that matches the given permalinks" do
        server = create(:server)
        expect(described_class["#{server.organization.permalink}/#{server.permalink}"]).to eq server
      end

      it "returns nil if no server exists" do
        expect(described_class["hello/world"]).to be nil
      end
    end
  end
end
