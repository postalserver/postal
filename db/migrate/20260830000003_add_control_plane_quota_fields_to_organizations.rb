# frozen_string_literal: true

class AddControlPlaneQuotaFieldsToOrganizations < ActiveRecord::Migration[7.0]

  def change
    add_column :organizations, :external_customer_id, :string
    add_column :organizations, :plan_code, :string
    add_column :organizations, :monthly_outbound_limit, :bigint
    add_column :organizations, :quota_warning_percent, :integer, default: 80, null: false
    add_column :organizations, :quota_action, :string, default: "monitor", null: false
    add_index :organizations, :external_customer_id
  end

end
