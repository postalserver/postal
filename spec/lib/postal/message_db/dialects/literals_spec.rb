# frozen_string_literal: true

require "rails_helper"

# A dialect builds SQL by interpolating, so anything it puts inside a string
# literal has to be escaped. Identifiers have their own rule, which
# quote_identifier applies; the values compared against catalog columns are
# literals, where SQL escapes a quote by doubling it.
RSpec.describe "message database dialect literals" do
  let(:quoted) { "a'name" }

  [["mysql", Postal::MessageDB::Dialects::MySQL],
   ["postgresql", Postal::MessageDB::Dialects::PostgreSQL],].each do |name, dialect_class|
    context "for #{name}" do
      let(:dialect) { dialect_class.new }

      it "escapes the namespace when checking whether it exists" do
        sql = dialect.namespace_exists_sql(quoted)

        expect(sql).to include("'a''name'")
        expect(sql).to_not include("'a'name'")
      end
    end
  end

  context "for postgresql" do
    let(:dialect) { Postal::MessageDB::Dialects::PostgreSQL.new }

    it "escapes the namespace and the pattern when listing tables" do
      sql = dialect.list_tables_sql(quoted, "raw-'%")

      expect(sql).to include("'a''name'")
      expect(sql).to include("'raw-''%'")
    end
  end
end
