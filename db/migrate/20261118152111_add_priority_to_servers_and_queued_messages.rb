class AddPriorityToServersAndQueuedMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :servers, :priority, :integer, default: 50, null: false
    add_column :queued_messages, :priority, :integer, default: 50, null: false
    add_index :queued_messages, [:priority, :id], order: { priority: :desc }
  end
end
