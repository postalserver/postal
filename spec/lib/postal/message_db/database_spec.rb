# frozen_string_literal: true

require "rails_helper"

describe Postal::MessageDB::Database do
  context "when provisioned" do
    let(:server) { create(:server) }
    subject(:database) { server.message_db }

    it "should be a message db" do
      expect(database).to be_a Postal::MessageDB::Database
    end

    it "should return the current schema version" do
      expect(database.schema_version).to be_a Integer
    end
  end
end
