class CreateCredentialLimits < ActiveRecord::Migration[5.2]
  def change
    create_table :credential_limits, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"  do |t|
      t.integer :credential_id
      t.string :type
      t.integer :limit
      t.integer :usage
    end
  end
end
