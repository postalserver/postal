# frozen_string_literal: true

# == Schema Information
#
# Table name: worker_roles
#
#  id          :bigint           not null, primary key
#  acquired_at :datetime
#  role        :string(255)
#  worker      :string(255)
#
# Indexes
#
#  index_worker_roles_on_role  (role) UNIQUE
#
require "rails_helper"

RSpec.describe WorkerRole do
  let(:locker_name) { "test" }

  before do
    allow(Postal).to receive(:locker_name).and_return(locker_name)
  end

  describe ".acquire" do
    context "when there are no existing roles" do
      it "returns :created" do
        expect(WorkerRole.acquire("test")).to eq(:created)
      end
    end

    context "when the current process holds a lock for a role" do
      it "returns :renewed" do
        create(:worker_role, role: "test", worker: "test", acquired_at: 1.minute.ago)
        expect(WorkerRole.acquire("test")).to eq(:renewed)
      end
    end

    context "when the role has become stale" do
      it "returns :stolen" do
        create(:worker_role, role: "test", worker: "another", acquired_at: 10.minute.ago)
        expect(WorkerRole.acquire("test")).to eq(:stolen)
      end
    end

    context "when the role is already locked by another worker" do
      it "returns false" do
        create(:worker_role, role: "test", worker: "another", acquired_at: 1.minute.ago)
        expect(WorkerRole.acquire("test")).to eq(false)
      end
    end
  end

  describe ".release" do
    context "when the role is locked by the current worker" do
      it "deletes the role and returns true" do
        role = create(:worker_role, role: "test", worker: "test")
        expect(WorkerRole.release("test")).to eq(true)
        expect(WorkerRole.find_by(id: role.id)).to be_nil
      end
    end

    context "when the role is locked by another worker" do
      it "does not delete the role and returns false" do
        role = create(:worker_role, role: "test", worker: "another")
        expect(WorkerRole.release("test")).to eq(false)
        expect(WorkerRole.find_by(id: role.id)).to be_present
      end
    end
  end
end
