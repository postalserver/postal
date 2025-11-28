#!/bin/bash
# Quick fix script for proxy email sending issue
# This script applies the SQL migrations directly to the database

set -e

echo "=================================================="
echo "Postal Proxy Fix - Database Migration Script"
echo "=================================================="
echo ""

# Get database connection details from postal.yml
if [ -f /opt/postal/config/postal.yml ]; then
    echo "Reading database config from /opt/postal/config/postal.yml..."

    # Try to use yq if available, otherwise use grep/awk
    if command -v yq &> /dev/null; then
        DB_HOST=$(yq eval '.main_db.host' /opt/postal/config/postal.yml)
        DB_PORT=$(yq eval '.main_db.port' /opt/postal/config/postal.yml)
        DB_USER=$(yq eval '.main_db.username' /opt/postal/config/postal.yml)
        DB_PASS=$(yq eval '.main_db.password' /opt/postal/config/postal.yml)
        DB_NAME=$(yq eval '.main_db.database' /opt/postal/config/postal.yml)
    else
        DB_HOST=$(grep -A 5 "main_db:" /opt/postal/config/postal.yml | grep "host:" | awk '{print $2}')
        DB_PORT=$(grep -A 5 "main_db:" /opt/postal/config/postal.yml | grep "port:" | awk '{print $2}')
        DB_USER=$(grep -A 5 "main_db:" /opt/postal/config/postal.yml | grep "username:" | awk '{print $2}')
        DB_PASS=$(grep -A 5 "main_db:" /opt/postal/config/postal.yml | grep "password:" | awk '{print $2}')
        DB_NAME=$(grep -A 5 "main_db:" /opt/postal/config/postal.yml | grep "database:" | awk '{print $2}')
    fi
else
    echo "Config file not found. Using default values."
    DB_HOST="${DB_HOST:-127.0.0.1}"
    DB_PORT="${DB_PORT:-3306}"
    DB_USER="${DB_USER:-postal}"
    DB_PASS="${DB_PASS:-}"
    DB_NAME="${DB_NAME:-postal}"
fi

echo "Database: $DB_NAME"
echo "Host: $DB_HOST:$DB_PORT"
echo "User: $DB_USER"
echo ""

# Apply the SQL migrations
echo "Applying proxy migrations to database..."
if [ -n "$DB_PASS" ]; then
    mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < apply_proxy_migrations.sql
else
    mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" "$DB_NAME" < apply_proxy_migrations.sql
fi

echo ""
echo "✅ Migrations applied successfully!"
echo ""
echo "Next steps:"
echo "1. Restart Postal: postal stop && postal start"
echo "2. Check logs for [PROXY DEBUG] messages"
echo "3. Send a test email and verify the IP address"
echo ""
