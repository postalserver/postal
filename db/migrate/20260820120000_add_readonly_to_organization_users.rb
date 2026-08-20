# frozen_string_literal: true

class AddReadonlyToOrganizationUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :organization_users, :read_only, :boolean, default: false, null: false
  end
end
