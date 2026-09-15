# frozen_string_literal: true

require "rails_helper"

# Active Record's serialization defaults have changed across recent Rails
# releases (`config.active_record.default_column_serializer` becomes `nil` in
# the 7.1 defaults, which makes an implicit coder an error rather than YAML).
# These columns hold data written by older versions of Postal, so the on-disk
# format has to stay YAML. These examples pin both the format and the round trip
# so a future framework defaults bump cannot change them silently.
RSpec.describe "serialized columns" do
  shared_examples "a YAML serialized hash column" do |attribute|
    let(:value) { { "string" => "value", "number" => 123, "nested" => { "a" => [1, 2] } } }

    def write_raw(record, attribute, raw)
      sql = described_class.sanitize_sql_array(
        ["UPDATE #{described_class.table_name} SET #{attribute} = ? WHERE id = ?", raw, record.id]
      )
      described_class.connection.update(sql)
    end

    def read_raw(record, attribute)
      described_class.connection.select_value(
        described_class.sanitize_sql_array(
          ["SELECT #{attribute} FROM #{described_class.table_name} WHERE id = ?", record.id]
        )
      )
    end

    it "defaults to an empty hash" do
      expect(described_class.new.public_send(attribute)).to eq({})
    end

    it "round trips a hash through the database" do
      record.update!(attribute => value)
      expect(record.reload.public_send(attribute)).to eq value
    end

    it "stores the value as YAML in the database" do
      record.update!(attribute => value)
      raw = read_raw(record, attribute)

      expect(raw).to be_a String
      expect(YAML.safe_load(raw)).to eq value
    end

    it "reads YAML which was written by a previous version of Postal" do
      write_raw(record, attribute, value.to_yaml)
      expect(record.reload.public_send(attribute)).to eq value
    end

    it "rejects a value which is not a hash" do
      expect { record.update!(attribute => "not a hash") }.to raise_error ActiveRecord::SerializationTypeMismatch
    end
  end

  describe Credential do
    let(:record) { create(:credential) }

    include_examples "a YAML serialized hash column", :options
  end

  describe WebhookRequest do
    let(:record) { create(:webhook_request) }

    include_examples "a YAML serialized hash column", :payload
  end
end
