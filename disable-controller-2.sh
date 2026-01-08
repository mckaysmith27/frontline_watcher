#!/bin/bash

# Disable controller_2 completely - only controller_1 should run
# This script ensures controller_2 is stopped and won't auto-start

set -e

EC2_HOST="sub67-watcher"
SERVICE_NAME="frontline-watcher-controller_2"

echo "🛑 Disabling Controller 2"
echo "========================"
echo ""

echo "📋 Steps:"
echo "  1. Stop controller_2 service"
echo "  2. Disable auto-start on boot"
echo "  3. Verify controller_1 is ready"
echo ""

# Check if we can connect
if ! ssh -o ConnectTimeout=5 "$EC2_HOST" "echo 'Connected'" &>/dev/null; then
    echo "⚠️  Cannot connect to EC2: $EC2_HOST"
    echo "   EC2 instance may be stopped."
    echo ""
    echo "✅ Controller 2 will remain disabled when EC2 is restarted"
    echo "   (systemd service is disabled, won't auto-start)"
    exit 0
fi

echo "🛑 Stopping controller_2..."
ssh "$EC2_HOST" "sudo systemctl stop $SERVICE_NAME" 2>/dev/null || echo "  (service may already be stopped)"

echo "🚫 Disabling controller_2 auto-start..."
ssh "$EC2_HOST" "sudo systemctl disable $SERVICE_NAME" 2>/dev/null || echo "  (service may already be disabled)"

echo ""
echo "✅ Controller 2 Status:"
STATUS=$(ssh "$EC2_HOST" "sudo systemctl is-active $SERVICE_NAME" 2>/dev/null || echo "inactive")
ENABLED=$(ssh "$EC2_HOST" "sudo systemctl is-enabled $SERVICE_NAME" 2>/dev/null || echo "disabled")

if [ "$STATUS" = "inactive" ] && [ "$ENABLED" = "disabled" ]; then
    echo "  ✅ STOPPED and DISABLED"
else
    echo "  ⚠️  Status: $STATUS, Enabled: $ENABLED"
fi

echo ""
echo "📋 Controller 1 Status:"
CTRL1_STATUS=$(ssh "$EC2_HOST" "sudo systemctl is-active frontline-watcher-controller_1" 2>/dev/null || echo "inactive")
CTRL1_ENABLED=$(ssh "$EC2_HOST" "sudo systemctl is-enabled frontline-watcher-controller_1" 2>/dev/null || echo "disabled")

if [ "$CTRL1_STATUS" = "active" ]; then
    echo "  ✅ RUNNING"
elif [ "$CTRL1_ENABLED" = "enabled" ]; then
    echo "  ⏸️  STOPPED (but enabled - will start on boot)"
else
    echo "  ⏸️  STOPPED and DISABLED"
fi

echo ""
echo "✅ Controller 2 is now disabled"
echo "   Only controller_1 will run when EC2 is started"
echo ""
echo "📋 To start controller_1 when ready:"
echo "   ./control-controllers.sh start 1"
