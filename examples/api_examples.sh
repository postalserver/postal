#!/bin/bash
#
# Postal Management API - Bash Examples
#
# Configuration:
#   export POSTAL_URL="https://postal.example.com"
#   export POSTAL_MANAGEMENT_API_KEY="your-secret-key"
#

POSTAL_URL="${POSTAL_URL:-https://postal.example.com}"
API_KEY="${POSTAL_MANAGEMENT_API_KEY}"

# Helper function for API calls
postal_api() {
    local method="$1"
    local endpoint="$2"
    local data="$3"

    if [ -n "$data" ]; then
        curl -s -X "$method" \
            "${POSTAL_URL}/management/api/v1${endpoint}" \
            -H "X-Management-API-Key: ${API_KEY}" \
            -H "Content-Type: application/json" \
            -d "$data"
    else
        curl -s -X "$method" \
            "${POSTAL_URL}/management/api/v1${endpoint}" \
            -H "X-Management-API-Key: ${API_KEY}" \
            -H "Content-Type: application/json"
    fi
}

# ============================================
# IP POOLS
# ============================================

# Get all IP pools
get_ip_pools() {
    echo "=== Getting IP Pools ==="
    postal_api GET "/ip_pools" | jq .
}

# Get IP pools for organization
get_org_ip_pools() {
    local org="$1"
    echo "=== Getting IP Pools for ${org} ==="
    postal_api GET "/organizations/${org}/ip_pools" | jq .
}

# ============================================
# SERVERS
# ============================================

# List all servers
list_servers() {
    echo "=== Listing Servers ==="
    postal_api GET "/servers" | jq .
}

# Create a new server
# Usage: create_server "org-permalink" "ServerName" ip_pool_id
create_server() {
    local org="$1"
    local name="$2"
    local ip_pool_id="$3"

    echo "=== Creating Server '${name}' ==="
    postal_api POST "/servers" "{
        \"organization\": \"${org}\",
        \"name\": \"${name}\",
        \"ip_pool_id\": ${ip_pool_id:-null},
        \"mode\": \"Live\",
        \"message_retention_days\": 2,
        \"raw_message_retention_days\": 2,
        \"raw_message_retention_size\": 12048
    }" | jq .
}

# Get server details
# Usage: get_server "org/server" OR get_server server_id
get_server() {
    local server_id="$1"
    echo "=== Getting Server ${server_id} ==="
    postal_api GET "/servers/${server_id}" | jq .
}

# Update server retention settings
update_server_retention() {
    local server_id="$1"
    echo "=== Updating Server Retention ==="
    postal_api PATCH "/servers/${server_id}" '{
        "message_retention_days": 2,
        "raw_message_retention_days": 2,
        "raw_message_retention_size": 12048
    }' | jq .
}

# ============================================
# DOMAINS
# ============================================

# List domains for a server
# Usage: list_domains "org/server" OR list_domains server_id
list_domains() {
    local server_id="$1"
    echo "=== Listing Domains for ${server_id} ==="
    postal_api GET "/servers/${server_id}/domains" | jq .
}

# Add a domain to a server
# Usage: add_domain "org/server" "example.com"
add_domain() {
    local server_id="$1"
    local domain_name="$2"

    echo "=== Adding Domain '${domain_name}' ==="
    postal_api POST "/servers/${server_id}/domains" "{
        \"name\": \"${domain_name}\",
        \"auto_verify\": true
    }" | jq .
}

# Get DNS records for a domain
# Usage: get_dns_records "org/server" "domain-uuid"
get_dns_records() {
    local server_id="$1"
    local domain_uuid="$2"

    echo "=== Getting DNS Records ==="
    postal_api GET "/servers/${server_id}/domains/${domain_uuid}/dns_records" | jq .
}

# Check DNS configuration
# Usage: check_dns "org/server" "domain-uuid"
check_dns() {
    local server_id="$1"
    local domain_uuid="$2"

    echo "=== Checking DNS ==="
    postal_api POST "/servers/${server_id}/domains/${domain_uuid}/check_dns" | jq .
}

# ============================================
# CREDENTIALS
# ============================================

# List credentials for a server
list_credentials() {
    local server_id="$1"
    echo "=== Listing Credentials ==="
    postal_api GET "/servers/${server_id}/credentials" | jq .
}

# Create API credential
# Usage: create_api_credential "org/server" "Credential Name"
create_api_credential() {
    local server_id="$1"
    local name="$2"

    echo "=== Creating API Credential ==="
    postal_api POST "/servers/${server_id}/credentials" "{
        \"name\": \"${name}\",
        \"type\": \"API\"
    }" | jq .
}

# ============================================
# WEBHOOKS
# ============================================

# List webhooks for a server
list_webhooks() {
    local server_id="$1"
    echo "=== Listing Webhooks ==="
    postal_api GET "/servers/${server_id}/webhooks" | jq .
}

# Create webhook for bounces only
# Usage: create_bounce_webhook "org/server" "webhook-name" "https://example.com/bounces"
create_bounce_webhook() {
    local server_id="$1"
    local name="$2"
    local url="$3"

    echo "=== Creating Bounce Webhook ==="
    postal_api POST "/servers/${server_id}/webhooks" "{
        \"name\": \"${name}\",
        \"url\": \"${url}\",
        \"events\": [\"MessageDeliveryFailed\", \"MessageBounced\"],
        \"all_events\": false,
        \"enabled\": true,
        \"sign\": true
    }" | jq .
}

# ============================================
# FULL SETUP EXAMPLE
# ============================================

# Complete setup: server + domain + webhook
# Usage: full_setup "org" "ServerName" "example.com" ip_pool_id "https://example.com/bounces"
full_setup() {
    local org="$1"
    local server_name="$2"
    local domain_name="$3"
    local ip_pool_id="$4"
    local webhook_url="$5"

    echo "=========================================="
    echo "FULL POSTAL SETUP"
    echo "=========================================="

    # 1. Create server
    echo ""
    echo "Step 1: Creating server..."
    local server_result=$(postal_api POST "/servers" "{
        \"organization\": \"${org}\",
        \"name\": \"${server_name}\",
        \"ip_pool_id\": ${ip_pool_id:-null},
        \"mode\": \"Live\",
        \"message_retention_days\": 2,
        \"raw_message_retention_days\": 2,
        \"raw_message_retention_size\": 12048
    }")

    local server_id=$(echo "$server_result" | jq -r '.data.server.id')
    local api_key=$(echo "$server_result" | jq -r '.data.credentials.api_key')

    echo "Server ID: ${server_id}"
    echo "API Key: ${api_key}"

    # 2. Add domain
    echo ""
    echo "Step 2: Adding domain..."
    local domain_result=$(postal_api POST "/servers/${server_id}/domains" "{
        \"name\": \"${domain_name}\",
        \"auto_verify\": true
    }")

    local domain_uuid=$(echo "$domain_result" | jq -r '.data.domain.uuid')
    echo "Domain UUID: ${domain_uuid}"

    # 3. Get DNS records
    echo ""
    echo "Step 3: DNS Records to configure:"
    postal_api GET "/servers/${server_id}/domains/${domain_uuid}/dns_records" | jq '.data.records'

    # 4. Create webhook
    if [ -n "$webhook_url" ]; then
        echo ""
        echo "Step 4: Creating webhook..."
        postal_api POST "/servers/${server_id}/webhooks" "{
            \"name\": \"${domain_name}\",
            \"url\": \"${webhook_url}\",
            \"events\": [\"MessageDeliveryFailed\", \"MessageBounced\"],
            \"enabled\": true
        }" | jq '.data.webhook'
    fi

    echo ""
    echo "=========================================="
    echo "SETUP COMPLETE"
    echo "=========================================="
    echo "Server: ${org}/${server_name}"
    echo "API Key: ${api_key}"
    echo "Domain: ${domain_name}"
    echo ""
    echo "Next steps:"
    echo "1. Configure DNS records shown above"
    echo "2. Run: check_dns ${server_id} ${domain_uuid}"
    echo "=========================================="
}

# Show help
show_help() {
    echo "Postal Management API - Bash Examples"
    echo ""
    echo "Functions available:"
    echo "  get_ip_pools                              - List all IP pools"
    echo "  get_org_ip_pools <org>                    - List IP pools for organization"
    echo "  list_servers                              - List all servers"
    echo "  create_server <org> <name> [ip_pool_id]   - Create a new server"
    echo "  get_server <server_id>                    - Get server details"
    echo "  list_domains <server_id>                  - List domains"
    echo "  add_domain <server_id> <domain>           - Add domain"
    echo "  get_dns_records <server_id> <domain_uuid> - Get DNS records"
    echo "  check_dns <server_id> <domain_uuid>       - Check DNS configuration"
    echo "  list_credentials <server_id>              - List credentials"
    echo "  create_api_credential <server_id> <name>  - Create API credential"
    echo "  list_webhooks <server_id>                 - List webhooks"
    echo "  create_bounce_webhook <server_id> <name> <url> - Create bounce webhook"
    echo "  full_setup <org> <server> <domain> <ip_pool_id> <webhook_url>"
    echo ""
    echo "Configuration:"
    echo "  export POSTAL_URL=https://postal.example.com"
    echo "  export POSTAL_MANAGEMENT_API_KEY=your-key"
}

# Run if sourced with argument
if [ "$1" = "help" ]; then
    show_help
fi
