#!/bin/bash
# Check and update controller_1 credentials on EC2
# Usage: ./check-controller-credentials.sh [ec2-host]

set -e

EC2_HOST="${1:-sub67-watcher}"
APP_DIR="/opt/frontline-watcher"
ENV_FILE="${APP_DIR}/.env.controller_1"

echo "🔍 Checking Controller 1 Credentials"
echo "======================================"
echo "EC2 Host: $EC2_HOST"
echo ""

# Check if we can connect
if ! ssh "$EC2_HOST" "echo 'Connected'" &>/dev/null; then
    echo "❌ Cannot connect to $EC2_HOST"
    echo "   Make sure you can SSH to the EC2 instance"
    exit 1
fi

echo "📋 Current Configuration:"
echo "-------------------------"
ssh "$EC2_HOST" << 'EOF'
    APP_DIR="/opt/frontline-watcher"
    ENV_FILE="${APP_DIR}/.env.controller_1"
    
    if [ -f "$ENV_FILE" ]; then
        echo "✅ Environment file exists: $ENV_FILE"
        echo ""
        echo "Current values (passwords hidden):"
        grep -E "^(CONTROLLER_ID|DISTRICT_ID|FRONTLINE_USERNAME|FRONTLINE_PASSWORD)" "$ENV_FILE" | \
            sed 's/FRONTLINE_PASSWORD=.*/FRONTLINE_PASSWORD=***HIDDEN***/' || true
    else
        echo "❌ Environment file not found: $ENV_FILE"
        echo ""
        echo "Available .env files:"
        ls -la "${APP_DIR}/.env"* 2>/dev/null || echo "  No .env files found"
    fi
    
    echo ""
    echo "Service Status:"
    sudo systemctl status frontline-watcher-controller_1 --no-pager -l | head -20 || echo "  Service not found or not running"
EOF

echo ""
echo "📝 Recent Logs (last 20 lines):"
echo "------------------------------"
ssh "$EC2_HOST" "sudo journalctl -u frontline-watcher-controller_1 -n 20 --no-pager" 2>/dev/null || echo "  No logs available"

echo ""
echo ""
echo "🔧 To Update Credentials:"
echo "-------------------------"
echo "1. Run this script with update option:"
echo "   ./update-controller-credentials.sh $EC2_HOST"
echo ""
echo "2. Or manually edit on EC2:"
echo "   ssh $EC2_HOST"
echo "   sudo nano $ENV_FILE"
echo "   sudo systemctl restart frontline-watcher-controller_1"
echo ""
