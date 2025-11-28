# frozen_string_literal: true

class AddProxyFieldsToIPAddresses < ActiveRecord::Migration[7.1]
  def change
    add_column :ip_addresses, :use_proxy, :boolean, default: false
    add_column :ip_addresses, :proxy_type, :string, default: "socks5"
    add_column :ip_addresses, :proxy_host, :string
    add_column :ip_addresses, :proxy_port, :integer, default: 1080
    add_column :ip_addresses, :proxy_username, :string
    add_column :ip_addresses, :proxy_password, :string
    add_column :ip_addresses, :proxy_auto_install, :boolean, default: false
    add_column :ip_addresses, :proxy_ssh_host, :string
    add_column :ip_addresses, :proxy_ssh_port, :integer, default: 22
    add_column :ip_addresses, :proxy_ssh_username, :string, default: "root"
    add_column :ip_addresses, :proxy_ssh_password, :string
    add_column :ip_addresses, :proxy_status, :string, default: "not_configured"
    add_column :ip_addresses, :proxy_last_tested_at, :datetime
    add_column :ip_addresses, :proxy_last_test_result, :text
  end
end
