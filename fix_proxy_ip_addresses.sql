-- Fix existing proxy IP addresses that have use_proxy=true but missing proxy_host/proxy_port
-- This SQL can be run manually if Rails migration cannot be executed

UPDATE ip_addresses
SET proxy_host = proxy_ssh_host,
    proxy_port = 1080,
    proxy_type = 'socks5'
WHERE use_proxy = true
  AND proxy_ssh_host IS NOT NULL
  AND proxy_ssh_host != ''
  AND (proxy_host IS NULL OR proxy_host = '');

-- Show affected rows
SELECT id, ipv4, hostname, use_proxy, proxy_ssh_host, proxy_host, proxy_port, proxy_status
FROM ip_addresses
WHERE use_proxy = true;
