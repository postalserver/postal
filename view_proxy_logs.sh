#!/bin/bash
# Script to view proxy installation logs in real-time

echo "==================================================================="
echo "POSTAL PROXY INSTALLATION LOGS"
echo "==================================================================="
echo ""

# Check if Rails server is running
if pgrep -f "rails server" > /dev/null; then
    echo "✅ Rails server is running"
    echo ""
fi

# Find the log file
if [ -f "log/development.log" ]; then
    echo "📄 Watching development.log for proxy-related messages..."
    echo "   (Press Ctrl+C to stop)"
    echo ""
    echo "-------------------------------------------------------------------"

    # Show last 50 lines with proxy-related messages
    echo "RECENT PROXY LOGS (last 50 lines):"
    echo "-------------------------------------------------------------------"
    grep -i "proxy" log/development.log | tail -50

    echo ""
    echo "-------------------------------------------------------------------"
    echo "LIVE TAIL (new messages will appear below):"
    echo "-------------------------------------------------------------------"
    tail -f log/development.log | grep --line-buffered -i "proxy\|error\|installer"
else
    echo "❌ Log file not found: log/development.log"
    echo "   Rails may not be running or logging is not configured."
fi
