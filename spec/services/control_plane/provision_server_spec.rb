# frozen_string_literal: true

require "rails_helper"

RSpec.describe ControlPlane::ProvisionServer do
  let(:organization) { create(:organization) }

  it "removes the main record when message database provisioning fails" do
    provisioner = instance_double("provisioner", provision: nil, drop: nil, clean: nil)
    provision_error = Mysql2::Error.new("CREATE command denied to user")
    allow_any_instance_of(Postal::MessageDB::Database).to receive(:provisioner).and_return(provisioner)
    allow(provisioner).to receive(:provision).and_raise(provision_error)
    allow(Rails.logger).to receive(:error)

    expect do
      described_class.new(organization: organization, attributes: { name: "Control Plane", permalink: "control-plane", mode: "Live" }).call
    end.to raise_error(ControlPlane::ProvisionServer::ProvisioningError) { |error|
      expect(error.cause).to eq(provision_error)
    }
    expect(organization.servers.where(permalink: "control-plane")).to be_empty
    expect(provisioner).to have_received(:drop)
    expect(Rails.logger).to have_received(:error).with(
      match(/Message database provisioning failed.*Mysql2::Error: CREATE command denied/)
    )
  end
end
