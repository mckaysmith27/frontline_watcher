#!/bin/bash

# Ensure controller_2 is completely disabled
# Run this when EC2 comes back online to ensure only controller_1 runs

set -e

EC2_HOST="sub67-watcher"
SERVICE_NAME="frontline-watcher-controller_2"

echo "🛑 Ensuring Controller 2 is Disabled"
echo "======================================"
echo ""

# Check if we can connect
if ! ssh -o ConnectTimeout=5 "$EC2_HOST" "echo 'Connected'" &>/dev/null; then
    echo "⚠️  Cannot connect to EC2: $EC2_HOST"
    echo "   EC2 instance appears to be stopped."
    echo ""
    echo "📋 When EC2 comes back online, run this script again:"
    echo "   ./ensure-controller-2-disabled.sh"
    exit 0
fi

echo "🛑 Stopping controller_2 (if running)..."
ssh "$EC2_HOST" "sudo systemctl stop $SERVICE_NAME" 2>/dev/null || true

echo "🚫 Disabling controller_2 auto-start..."
ssh "$EC2_HOST" "sudo systemctl disable $SERVICE_NAME" 2>/dev/null || true

echo ""
echo "✅ Verification:"
STATUS=$(ssh "$EC2_HOST" "sudo systemctl is-active $SERVICE_NAME" 2>/dev/null || echo "inactive")
ENABLED=$(ssh "$EC2_HOST" "sudo systemctl is-enabled $SERVICE_NAME" 2>/dev/null || echo "disabled")

if [ "$STATUS" = "inactive" ] && [ "$ENABLED" = "disabled" ]; then
    echo "  ✅ Controller 2: STOPPED and DISABLED"
else
    echo "  ⚠️  Controller 2: Status=$STATUS, Enabled=$ENABLED"
    echo "     Attempting to fix..."
    ssh "$EC2_HOST" "sudo systemctl stop $SERVICE_NAME && sudo systemctl disable $SERVICE_NAME" 2>/dev/null || true
fi

echo ""
echo "📋 Controller 1 Status:"
CTRL1_STATUS=$(ssh "$EC2_HOST" "sudo systemctl is-active frontline-watcher-controller_1" 2>/dev/null || echo "inactive")
CTRL1_ENABLED=$(ssh "$EC2_HOST" "sudo systemctl is-enabled frontline-watcher-controller_1" 2>/dev/null || echo "disabled")

if [ "$CTRL1_STATUS" = "active" ]; then
    echo "  ✅ Controller 1: RUNNING"
elif [ "$CTRL1_ENABLED" = "enabled" ]; then
    echo "  ⏸️  Controller 1: STOPPED (enabled - will start on boot)"
else
    echo "  ⏸️  Controller 1: STOPPED and DISABLED"
fi

echo ""
echo "✅ Controller 2 is now disabled"
echo "   Only controller_1 will run"
echo ""
echo "📋 To start controller_1:"
echo "   ./control-controllers.sh start 1"
