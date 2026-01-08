#!/bin/bash

# Install a systemd service that disables controller_2 on boot
# This ensures controller_2 never starts, even if it was previously enabled
# Run this on EC2 to set up the auto-disable mechanism

set -e

APP_DIR="/opt/frontline-watcher"
SERVICE_NAME="disable-controller-2"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

echo "🔧 Installing auto-disable service for controller_2"
echo ""

# Create a systemd service that runs on boot to disable controller_2
sudo tee $SERVICE_FILE > /dev/null << 'EOF'
[Unit]
Description=Disable Frontline Watcher Controller 2 on Boot
After=network.target
Before=frontline-watcher-controller_2.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'systemctl stop frontline-watcher-controller_2 2>/dev/null || true; systemctl disable frontline-watcher-controller_2 2>/dev/null || true'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
sudo systemctl daemon-reload

# Enable this service so it runs on boot
sudo systemctl enable $SERVICE_NAME

# Run it immediately to disable controller_2 right now
sudo systemctl start $SERVICE_NAME

echo "✅ Auto-disable service installed and enabled"
echo ""
echo "📋 What this does:"
echo "  - Runs on every EC2 boot"
echo "  - Stops controller_2 if it's running"
echo "  - Disables controller_2 so it won't auto-start"
echo "  - Runs BEFORE controller_2 service starts"
echo ""
echo "✅ Controller_2 is now disabled and will stay disabled on boot"
