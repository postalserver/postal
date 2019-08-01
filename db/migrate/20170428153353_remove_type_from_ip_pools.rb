class RemoveTypeFromIPPools < ActiveRecord::Migration[5.2]
  def change
    remove_column :ip_pools, :type, :string
  end
end
