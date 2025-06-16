# frozen_string_literal: true

class AddOutputStyleToWebhooks < ActiveRecord::Migration[7.0]
  def change
    add_column :webhooks, :output_style, :string, default: 'postal'
  end
end
