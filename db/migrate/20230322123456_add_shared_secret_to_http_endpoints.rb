class AddSharedSecretToHttpEndpoints < ActiveRecord::Migration[5.2]
    def change
      add_column :http_endpoint, :shared_secret, :string
    end
  end