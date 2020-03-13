class AddColumnCredentialIdToDomains < ActiveRecord::Migration[5.2]
  def change
    add_column :domains, :credential_id, :integer
  end
end
