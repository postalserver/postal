# frozen_string_literal: true

class FixExistingProxyIPAddresses < ActiveRecord::Migration[7.1]
  def up
    # Update existing IP addresses that have use_proxy=true but missing proxy_host/proxy_port
    # This fixes IP addresses that were created before the auto_fill_proxy_fields fix

    execute <<-SQL
      UPDATE ip_addresses
      SET proxy_host = proxy_ssh_host,
          proxy_port = 1080,
          proxy_type = 'socks5'
      WHERE use_proxy = true
        AND proxy_ssh_host IS NOT NULL
        AND proxy_ssh_host != ''
        AND (proxy_host IS NULL OR proxy_host = '');
    SQL
  end

  def down
    # No need to revert - this is a data fix
  end
end
