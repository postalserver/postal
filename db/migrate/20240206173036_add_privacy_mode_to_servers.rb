# frozen_string_literal: true

class AddPrivacyModeToServers < ActiveRecord::Migration[6.1]

  def change
    add_column :servers, :privacy_mode, :boolean, default: false
  end

end
