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
end
