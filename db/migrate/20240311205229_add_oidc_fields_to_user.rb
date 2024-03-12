# frozen_string_literal: true

class AddOIDCFieldsToUser < ActiveRecord::Migration[7.0]

  def change
    add_column :users, :oidc_uid, :string
    add_column :users, :oidc_issuer, :string
  end

end
