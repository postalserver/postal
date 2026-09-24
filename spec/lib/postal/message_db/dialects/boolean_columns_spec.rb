# frozen_string_literal: true

require "rails_helper"

# SQLite has no boolean type and the sqlite3 gem does not coerce one, so the
# dialect normalises the columns MySQL reports as booleans back to true/false on
# read. That list is maintained by hand, and getting it wrong is silent and only
# visible on SQLite: the 0/1 integers it returns are truthy in Ruby, so a check
# like `if message.held` would invert while every test on MySQL still passed.
#
# Which columns need normalising is not a matter of opinion, so it is derived from
# the migrations which declare them rather than trusted to a list someone
# remembers to update.
RSpec.describe "the message database boolean columns" do
  # A column declared tinyint(1) is the one MySQL reports as a boolean: either in
  # the reference schema of a migration's columns hash, or in an add_column_sql
  # call.
  def declared_boolean_columns
    Dir[Rails.root.join("lib/postal/message_db/migrations/*.rb")].flat_map do |file|
      source = File.read(file)
      source.scan(/(\w+):\s*"tinyint\(1\)/).flatten +
        source.scan(/:(\w+),\s*"tinyint\(1\)/).flatten
    end.uniq.sort
  end

  it "are all normalised by the SQLite dialect" do
    expect(declared_boolean_columns).to be_present

    expect(Postal::MessageDB::Dialects::SQLite::BOOLEAN_COLUMNS.sort).to eq(declared_boolean_columns)
  end
end
