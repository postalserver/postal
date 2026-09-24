# frozen_string_literal: true

require "rails_helper"
require "open3"
require "json"

# A database built by `db:migrate` and one loaded from `db/schema.rb` must be
# structurally equivalent. The suite only ever sees the second — CI loads the
# schema — so without this the migrations could stop producing the schema the
# application actually runs against, and nothing would notice. That is not
# hypothetical: seven migrations could not run at all under Rails 8.1, and the
# datetime precision below drifted when the schema was written by hand.
#
# The comparison is structural rather than textual, so it asserts the schema and
# not the dumper's formatting, and columns are matched by name rather than
# position. Every difference is collected and reported: a first mismatch stops a
# comparison but never bounds one.
RSpec.describe "the database schema" do
  let(:scratch_database) { "postal_schema_check" }
  let(:dump_path) { Rails.root.join("tmp/migrated_schema.json").to_s }

  def structural_dump(connection)
    connection.tables.sort.to_h do |table|
      columns = connection.columns(table).to_h { |c| [c.name, [c.sql_type, c.null, c.default&.to_s]] }
      indexes = connection.indexes(table).to_h { |i| [i.name, [i.columns, i.unique]] }

      [table, { "columns" => columns, "indexes" => indexes }]
    end
  end

  def differences_between(loaded, migrated)
    found = []

    (loaded.keys - migrated.keys).each { |t| found << "table #{t}: in loaded, absent from migrated" }
    (migrated.keys - loaded.keys).each { |t| found << "table #{t}: in migrated, absent from loaded" }

    (loaded.keys & migrated.keys).sort.each do |table|
      loaded_columns = loaded[table]["columns"]
      migrated_columns = migrated[table]["columns"]

      (loaded_columns.keys - migrated_columns.keys).each { |c| found << "#{table}.#{c}: in loaded, absent from migrated" }
      (migrated_columns.keys - loaded_columns.keys).each { |c| found << "#{table}.#{c}: in migrated, absent from loaded" }

      (loaded_columns.keys & migrated_columns.keys).sort.each do |column|
        next if loaded_columns[column] == migrated_columns[column]

        type, null, default = loaded_columns[column]
        migrated_type, migrated_null, migrated_default = migrated_columns[column]
        parts = []
        parts << "type #{type.inspect} vs #{migrated_type.inspect}" if type != migrated_type
        parts << "null #{null.inspect} vs #{migrated_null.inspect}" if null != migrated_null
        parts << "default #{default.inspect} vs #{migrated_default.inspect}" if default != migrated_default
        found << "#{table}.#{column}: #{parts.join(', ')}"
      end

      loaded_indexes = loaded[table]["indexes"]
      migrated_indexes = migrated[table]["indexes"]

      (loaded_indexes.keys - migrated_indexes.keys).each { |i| found << "#{table}: index #{i} in loaded, absent from migrated" }
      (migrated_indexes.keys - loaded_indexes.keys).each { |i| found << "#{table}: index #{i} in migrated, absent from loaded" }

      (loaded_indexes.keys & migrated_indexes.keys).sort.each do |index|
        next if loaded_indexes[index] == migrated_indexes[index]

        found << "#{table}: index #{index} #{loaded_indexes[index].inspect} vs #{migrated_indexes[index].inspect}"
      end
    end

    found
  end

  it "produces the same schema when it is migrated as when it is loaded" do
    environment = { "RAILS_ENV" => "test", "MAIN_DB_DATABASE" => scratch_database }
    rails = lambda do |*arguments|
      Open3.capture3(environment, "bundle", "exec", "rails", *arguments, chdir: Rails.root.to_s)
    end

    # DDL is not transactional on MySQL, so this cannot run inside the test
    # database's transaction. A scratch database is migrated instead, and it is
    # deliberately not the test database: migrating that would destroy the
    # fixture the rest of the suite runs against.
    rails.call("db:drop")
    _out, err, status = rails.call("db:create")
    raise "the scratch database could not be created: #{err}" unless status.success?

    begin
      _out, err, status = rails.call("runner", "ActiveRecord::MigrationContext.new(Rails.root.join('db/migrate')).migrate")
      raise "the migrations did not replay: #{err}" unless status.success?

      # Written to a file rather than read from stdout, which carries the
      # application's own startup output.
      dump = "File.write(#{dump_path.inspect}, JSON.generate(" \
             "ActiveRecord::Base.connection.tables.sort.to_h { |t| c = ActiveRecord::Base.connection; " \
             "[t, { 'columns' => c.columns(t).to_h { |x| [x.name, [x.sql_type, x.null, x.default&.to_s]] }, " \
             "'indexes' => c.indexes(t).to_h { |i| [i.name, [i.columns, i.unique]] } }] }))"
      _out, err, status = rails.call("runner", dump)
      raise "the migrated schema could not be read: #{err}" unless status.success?

      migrated = JSON.parse(File.read(dump_path))
      loaded = JSON.parse(JSON.generate(structural_dump(ActiveRecord::Base.connection)))

      found = differences_between(loaded, migrated)

      # Written to stderr so the complete set survives whatever RSpec does with a
      # long failure message.
      warn "\n=== SCHEMA DIFFERENCES: #{found.size} ==="
      found.each { |difference| warn "  #{difference}" }
      warn "=== END ==="

      expect(found).to be_empty
    ensure
      rails.call("db:drop")
      FileUtils.rm_f(dump_path)
    end
  end
end
