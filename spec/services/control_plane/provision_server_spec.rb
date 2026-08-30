# frozen_string_literal: true

require "rails_helper"

RSpec.describe ControlPlane::ProvisionServer do
  let(:organization) { create(:organization) }

  it "removes the main record when message database provisioning fails" do
    provisioner = instance_double("provisioner", provision: nil, drop: nil, clean: nil)
    allow_any_instance_of(Postal::MessageDB::Database).to receive(:provisioner).and_return(provisioner)
    allow(provisioner).to receive(:provision).and_raise(StandardError)

    expect do
      described_class.new(organization: organization, attributes: { name: "Control Plane", permalink: "control-plane", mode: "Live" }).call
    end.to raise_error(ControlPlane::ProvisionServer::ProvisioningError)
    expect(organization.servers.where(permalink: "control-plane")).to be_empty
    expect(provisioner).to have_received(:drop)
  end
end
