# frozen_string_literal: true

class AddPendingDKIMFieldsToDomains < ActiveRecord::Migration[7.0]

  def change
    add_column :domains, :pending_dkim_private_key, :text
    add_column :domains, :pending_dkim_identifier_string, :string
  end

end
