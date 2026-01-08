#!/bin/bash

# Set up all 5 controllers on EC2 instance
# Run this after setup-ec2.sh and configuring credentials

set -e

APP_DIR="/opt/frontline-watcher"
NUM_CONTROLLERS="${1:-5}"

echo "🚀 Setting up $NUM_CONTROLLERS controllers on EC2"
echo ""

# Check if .env template exists
if [ ! -f "$APP_DIR/.env.template" ]; then
    echo "❌ Error: .env.template not found"
    echo "   Run setup-ec2.sh first"
    exit 1
fi

# Create .env files for each controller (SKIP controller_2)
echo "📝 Creating .env files for each controller..."
echo "⚠️  NOTE: Controller_2 is SKIPPED - only controller_1 will be set up"
for i in $(seq 1 $NUM_CONTROLLERS); do
    # SKIP controller_2 - never set it up
    if [ "$i" = "2" ]; then
        echo "  ⏭️  Skipping controller_2 (disabled)"
        continue
    fi
    
    CONTROLLER_ID="controller_${i}"
    ENV_FILE="${APP_DIR}/.env.${CONTROLLER_ID}"
    
    if [ ! -f "$ENV_FILE" ]; then
        cp "$APP_DIR/.env.template" "$ENV_FILE"
        # Update CONTROLLER_ID in the file
        sed -i "s/CONTROLLER_ID=.*/CONTROLLER_ID=${CONTROLLER_ID}/" "$ENV_FILE"
        echo "  ✅ Created $ENV_FILE"
    else
        echo "  ⚠️  $ENV_FILE already exists, skipping"
    fi
done

echo ""
echo "🔧 Installing systemd services (SKIP controller_2)..."
for i in $(seq 1 $NUM_CONTROLLERS); do
    # SKIP controller_2 - never install it
    if [ "$i" = "2" ]; then
        echo "  ⏭️  Skipping controller_2 installation (disabled)"
        continue
    fi
    
    CONTROLLER_ID="controller_${i}"
    echo ""
    echo "Installing service for $CONTROLLER_ID..."
    sudo ./install-service.sh "$CONTROLLER_ID"
done

echo ""
echo "✅ All services installed!"
echo ""
echo "📋 Next steps:"
echo "1. Edit .env files with your credentials:"
echo "   nano $APP_DIR/.env.controller_1"
echo "   nano $APP_DIR/.env.controller_2"
echo "   # ... repeat for all controllers"
echo ""
echo "2. Start all services:"
echo "   for i in {1..$NUM_CONTROLLERS}; do"
echo "     sudo systemctl start frontline-watcher-controller_\${i}"
echo "     sudo systemctl enable frontline-watcher-controller_\${i}"
echo "   done"
echo ""
echo "3. Check status:"
echo "   sudo systemctl status frontline-watcher-controller_1"
echo ""
echo "4. View logs:"
echo "   sudo journalctl -u frontline-watcher-controller_1 -f"
