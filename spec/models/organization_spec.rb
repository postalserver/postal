# frozen_string_literal: true

# == Schema Information
#
# Table name: organizations
#
#  id                :integer          not null, primary key
#  deleted_at        :datetime
#  name              :string(255)
#  permalink         :string(255)
#  suspended_at      :datetime
#  suspension_reason :string(255)
#  time_zone         :string(255)
#  uuid              :string(255)
#  created_at        :datetime
#  updated_at        :datetime
#  ip_pool_id        :integer
#  owner_id          :integer
#
# Indexes
#
#  index_organizations_on_permalink  (permalink)
#  index_organizations_on_uuid       (uuid)
#
require "rails_helper"

describe Organization do
  context "model" do
    subject(:organization) { create(:organization) }

    it "should have a UUID" do
      expect(organization.uuid).to be_a String
      expect(organization.uuid.length).to eq 36
    end
  end

  context "when an organization is soft destroyed" do
    let(:owner) { create(:user) }
    let!(:organization) { create(:organization, name: "Acme Inc", permalink: "acme-inc", owner: owner) }

    it "releases the permalink immediately so the short name is free again" do
      organization.soft_destroy

      expect(organization.reload.permalink).to eq "deleted-#{organization.uuid}"
      expect(organization.deleted_at).to be_present
    end

    it "allows a new organization to use the same permalink again" do
      organization.soft_destroy

      replacement = Organization.new(name: "Acme Inc", permalink: "acme-inc")
      replacement.owner = owner

      expect(replacement).to be_valid
      expect { replacement.save! }.not_to raise_error
    end

    it "generates the same permalink for a new organization with the same name" do
      organization.soft_destroy

      replacement = Organization.new(name: "Acme Inc")
      replacement.owner = owner
      replacement.valid?

      expect(replacement.permalink).to eq "acme-inc"
    end
  end
end
