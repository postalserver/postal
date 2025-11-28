-- SQL script to add proxy fields to ip_addresses table
-- This migration adds proxy support to the ip_addresses table

ALTER TABLE ip_addresses ADD COLUMN use_proxy BOOLEAN DEFAULT FALSE;
ALTER TABLE ip_addresses ADD COLUMN proxy_type VARCHAR(255) DEFAULT 'socks5';
ALTER TABLE ip_addresses ADD COLUMN proxy_host VARCHAR(255);
ALTER TABLE ip_addresses ADD COLUMN proxy_port INT DEFAULT 1080;
ALTER TABLE ip_addresses ADD COLUMN proxy_username VARCHAR(255);
ALTER TABLE ip_addresses ADD COLUMN proxy_password VARCHAR(255);
ALTER TABLE ip_addresses ADD COLUMN proxy_auto_install BOOLEAN DEFAULT FALSE;
ALTER TABLE ip_addresses ADD COLUMN proxy_ssh_host VARCHAR(255);
ALTER TABLE ip_addresses ADD COLUMN proxy_ssh_port INT DEFAULT 22;
ALTER TABLE ip_addresses ADD COLUMN proxy_ssh_username VARCHAR(255) DEFAULT 'root';
ALTER TABLE ip_addresses ADD COLUMN proxy_ssh_password VARCHAR(255);
ALTER TABLE ip_addresses ADD COLUMN proxy_status VARCHAR(255) DEFAULT 'not_configured';
ALTER TABLE ip_addresses ADD COLUMN proxy_last_tested_at DATETIME;
ALTER TABLE ip_addresses ADD COLUMN proxy_last_test_result TEXT;
