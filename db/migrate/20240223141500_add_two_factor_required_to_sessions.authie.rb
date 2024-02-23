# frozen_string_literal: true

# This migration comes from authie (originally 20220502180100)
class AddTwoFactorRequiredToSessions < ActiveRecord::Migration[6.1]

  def change
    add_column :authie_sessions, :skip_two_factor, :boolean, default: false
  end

end
