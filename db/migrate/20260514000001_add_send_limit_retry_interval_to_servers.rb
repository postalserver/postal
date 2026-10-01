# frozen_string_literal: true

class AddSendLimitRetryIntervalToServers < ActiveRecord::Migration[7.0]
  def change
    add_column :servers, :send_limit_retry_interval, :integer
  end
end
