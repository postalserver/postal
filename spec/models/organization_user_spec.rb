# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizationUser do
  subject(:membership) { build(:organization_user) }

  describe "#role" do
    it "returns admin when admin is true" do
      membership.admin = true
      expect(membership.role).to eq("admin")
    end

    it "returns readonly when read_only is true" do
      membership.read_only = true
      expect(membership.role).to eq("readonly")
    end

    it "returns member by default" do
      expect(membership.role).to eq("member")
    end
  end

  describe "#apply_role!" do
    before { membership.save! }

    it "sets readonly access" do
      membership.apply_role!("readonly")
      expect(membership.reload).to have_attributes(admin: false, read_only: true)
    end

    it "sets organization admin access" do
      membership.apply_role!("admin")
      expect(membership.reload).to have_attributes(admin: true, read_only: false)
    end

    it "sets member access" do
      membership.update!(admin: true, read_only: true)
      membership.apply_role!("member")
      expect(membership.reload).to have_attributes(admin: false, read_only: false)
    end
  end

  describe "#can_write?" do
    it "is false for readonly users" do
      membership.read_only = true
      expect(membership.can_write?).to be false
    end

    it "is true for members" do
      expect(membership.can_write?).to be true
    end
  end
end
