# frozen_string_literal: true

class AddLockFieldsToWebhookRequests < ActiveRecord::Migration[6.1]

  def change
    add_column :webhook_requests, :locked_by, :string
    add_column :webhook_requests, :locked_at, :datetime

    add_index :webhook_requests, :locked_by
  end

end
