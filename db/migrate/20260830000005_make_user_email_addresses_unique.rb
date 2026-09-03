# frozen_string_literal: true

class MakeUserEmailAddressesUnique < ActiveRecord::Migration[7.0]

  def change
    remove_index :users, :email_address
    add_index :users, :email_address, unique: true, length: 255
  end

end
