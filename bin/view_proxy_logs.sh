#!/bin/bash

# Script to view proxy installation logs for Postal
# Usage: ./bin/view_proxy_logs.sh [ip_address_id]

CONTAINER_NAME="postal-postal-1"

echo "=== Proxy Installation Logs Viewer ==="
echo ""

# Check if container name is correct
if ! docker ps --format '{{.Names}}' | grep -q "postal"; then
    echo "Looking for Postal containers..."
    docker ps --format 'table {{.Names}}\t{{.Status}}'
    echo ""
    echo "Please update CONTAINER_NAME in this script with the correct container name"
    exit 1
fi

# Function to view logs from database
view_db_logs() {
    local ip_id=$1

    echo "=== Viewing logs from database ==="

    if [ -z "$ip_id" ]; then
        # Show all recent proxy installations
        docker exec -it $CONTAINER_NAME postal rails runner "
            IPAddress.where.not(proxy_last_test_result: nil)
                      .order(updated_at: :desc)
                      .limit(10)
                      .each do |ip|
                puts '=' * 80
                puts \"IP Address ID: #{ip.id}\"
                puts \"Status: #{ip.proxy_status}\"
                puts \"Host: #{ip.proxy_ssh_host || ip.ipv4}\"
                puts \"Updated: #{ip.updated_at}\"
                puts '-' * 80
                puts ip.proxy_last_test_result
                puts '=' * 80
                puts ''
            end
        "
    else
        # Show specific IP address logs
        docker exec -it $CONTAINER_NAME postal rails runner "
            ip = IPAddress.find($ip_id)
            puts '=' * 80
            puts \"IP Address ID: #{ip.id}\"
            puts \"Status: #{ip.proxy_status}\"
            puts \"Host: #{ip.proxy_ssh_host || ip.ipv4}\"
            puts \"Updated: #{ip.updated_at}\"
            puts '-' * 80
            puts ip.proxy_last_test_result || 'No logs available'
            puts '=' * 80
        "
    fi
}

# Function to view Rails logs
view_rails_logs() {
    echo "=== Viewing recent Rails logs (ProxyInstaller) ==="
    docker logs $CONTAINER_NAME 2>&1 | grep -i "ProxyInstaller\|ProxyInstallerService" | tail -100
}

# Main menu
if [ "$1" == "--rails" ] || [ "$1" == "-r" ]; then
    view_rails_logs
elif [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "Usage:"
    echo "  $0                    # View all recent proxy installation logs from database"
    echo "  $0 <ip_address_id>    # View logs for specific IP address"
    echo "  $0 --rails            # View Rails application logs"
    echo "  $0 --help             # Show this help"
else
    view_db_logs "$1"
fi
