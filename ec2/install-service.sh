#!/bin/bash

# Install systemd service for Frontline Watcher
# Run this after setup-ec2.sh

set -e

APP_DIR="/opt/frontline-watcher"
CONTROLLER_ID="${1:-controller_1}"

# BLOCK controller_2 from ever being installed
if [ "$CONTROLLER_ID" = "controller_2" ]; then
    echo "❌ ERROR: Controller_2 is DISABLED and cannot be installed"
    echo "   Controller_2 has been permanently disabled to prevent rate limiting issues"
    echo "   Only controller_1 should be used"
    exit 1
fi

if [ ! -d "$APP_DIR" ]; then
    echo "❌ Error: Application directory $APP_DIR not found"
    echo "   Run setup-ec2.sh first"
    exit 1
fi

echo "🔧 Installing systemd service for $CONTROLLER_ID"
echo ""

# Create systemd service file
SERVICE_NAME="frontline-watcher-${CONTROLLER_ID}"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

sudo tee $SERVICE_FILE > /dev/null << EOF
[Unit]
Description=Frontline Watcher Scraper - ${CONTROLLER_ID}
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=${APP_DIR}
Environment="PATH=${APP_DIR}/venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=${APP_DIR}/venv/bin/python -u ${APP_DIR}/frontline_watcher_refactored.py
Restart=always
RestartSec=10
StandardOutput=append:/var/log/frontline-watcher/${CONTROLLER_ID}.log
StandardError=append:/var/log/frontline-watcher/${CONTROLLER_ID}.error.log

# Environment variables from .env file (controller-specific)
EnvironmentFile=${APP_DIR}/.env.${CONTROLLER_ID}

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
sudo systemctl daemon-reload

echo "✅ Service installed: $SERVICE_NAME"
echo ""
echo "📋 Service commands:"
echo "  Start:   sudo systemctl start $SERVICE_NAME"
echo "  Stop:    sudo systemctl stop $SERVICE_NAME"
echo "  Status:  sudo systemctl status $SERVICE_NAME"
echo "  Logs:    sudo journalctl -u $SERVICE_NAME -f"
echo "  Enable:  sudo systemctl enable $SERVICE_NAME  # Auto-start on boot"
echo ""
