class AddPriorityToServer < ActiveRecord::Migration[7.0]
  def change
    add_column :servers, :priority, :integer, limit: 2, unsigned: true, default: 0
  end
end
