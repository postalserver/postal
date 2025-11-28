-- ===================================================================
-- POSTAL PROXY MIGRATIONS - Manual SQL Script
-- ===================================================================
-- This script adds proxy support to IP addresses and fixes existing records
-- Run this if you cannot run Rails migrations
-- ===================================================================

-- Migration 1: Add proxy fields to ip_addresses table
-- (Equivalent to 20251127000001_add_proxy_fields_to_ip_addresses.rb)
-- ===================================================================

ALTER TABLE ip_addresses
ADD COLUMN IF NOT EXISTS use_proxy BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS proxy_type VARCHAR(255) DEFAULT 'socks5',
ADD COLUMN IF NOT EXISTS proxy_host VARCHAR(255),
ADD COLUMN IF NOT EXISTS proxy_port INT DEFAULT 1080,
ADD COLUMN IF NOT EXISTS proxy_username VARCHAR(255),
ADD COLUMN IF NOT EXISTS proxy_password VARCHAR(255),
ADD COLUMN IF NOT EXISTS proxy_auto_install BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS proxy_ssh_host VARCHAR(255),
ADD COLUMN IF NOT EXISTS proxy_ssh_port INT DEFAULT 22,
ADD COLUMN IF NOT EXISTS proxy_ssh_username VARCHAR(255) DEFAULT 'root',
ADD COLUMN IF NOT EXISTS proxy_ssh_password VARCHAR(255),
ADD COLUMN IF NOT EXISTS proxy_status VARCHAR(255) DEFAULT 'not_configured',
ADD COLUMN IF NOT EXISTS proxy_last_tested_at DATETIME,
ADD COLUMN IF NOT EXISTS proxy_last_test_result TEXT;

-- ===================================================================
-- Migration 2: Fix existing proxy IP addresses
-- (Equivalent to 20251128000001_fix_existing_proxy_ip_addresses.rb)
-- ===================================================================

UPDATE ip_addresses
SET proxy_host = proxy_ssh_host,
    proxy_port = 1080,
    proxy_type = 'socks5'
WHERE use_proxy = TRUE
  AND proxy_ssh_host IS NOT NULL
  AND proxy_ssh_host != ''
  AND (proxy_host IS NULL OR proxy_host = '');

-- ===================================================================
-- Verify the changes
-- ===================================================================

SELECT
    id,
    ipv4,
    hostname,
    use_proxy,
    proxy_ssh_host,
    proxy_host,
    proxy_port,
    proxy_status
FROM ip_addresses
ORDER BY id;

-- Show proxy configuration summary
SELECT
    COUNT(*) as total_ips,
    SUM(CASE WHEN use_proxy = TRUE THEN 1 ELSE 0 END) as proxy_enabled,
    SUM(CASE WHEN use_proxy = TRUE AND proxy_host IS NOT NULL THEN 1 ELSE 0 END) as proxy_configured
FROM ip_addresses;
