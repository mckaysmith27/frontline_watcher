#!/bin/bash

# Deploy Frontline Watcher to EC2 instance
# Usage: ./deploy-to-ec2.sh <ec2-host> <controller-id>
# Example: ./deploy-to-ec2.sh ec2-user@your-ec2-instance.compute-1.amazonaws.com controller_1

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <ec2-host> <controller-id>"
    echo "Example: $0 ec2-user@ec2-54-123-45-67.compute-1.amazonaws.com controller_1"
    exit 1
fi

EC2_HOST="$1"
CONTROLLER_ID="$2"
APP_DIR="/opt/frontline-watcher"

echo "🚀 Deploying Frontline Watcher to EC2"
echo "Host: $EC2_HOST"
echo "Controller: $CONTROLLER_ID"
echo ""

# Create temporary deployment directory
TEMP_DIR=$(mktemp -d)
echo "📦 Creating deployment package..."

# Copy necessary files
cp frontline_watcher_refactored.py "$TEMP_DIR/frontline_watcher.py"
cp requirements_raw.txt "$TEMP_DIR/"

# Create deployment archive
cd "$TEMP_DIR"
tar czf deploy.tar.gz frontline_watcher.py requirements_raw.txt
cd - > /dev/null

echo "📤 Uploading files to EC2..."
scp "$TEMP_DIR/deploy.tar.gz" "$EC2_HOST:/tmp/"

echo "🔧 Installing on EC2..."
ssh "$EC2_HOST" << EOF
set -e

# Extract files
sudo mkdir -p $APP_DIR
cd $APP_DIR
sudo tar xzf /tmp/deploy.tar.gz
sudo chown -R \$USER:\$USER $APP_DIR

# Update virtual environment if it exists
if [ -d "$APP_DIR/venv" ]; then
    echo "Updating virtual environment..."
    source $APP_DIR/venv/bin/activate
    pip install -r requirements_raw.txt
    playwright install chromium
    playwright install-deps chromium
else
    echo "Virtual environment not found. Run setup-ec2.sh first."
    exit 1
fi

# Restart service if it exists
if systemctl is-active --quiet frontline-watcher-${CONTROLLER_ID}; then
    echo "Restarting service..."
    sudo systemctl restart frontline-watcher-${CONTROLLER_ID}
    echo "✅ Service restarted"
else
    echo "⚠️  Service not running. Install with: sudo ./install-service.sh ${CONTROLLER_ID}"
fi

# Cleanup
rm /tmp/deploy.tar.gz
EOF

# Cleanup local temp files
rm -rf "$TEMP_DIR"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Check service status:"
echo "  ssh $EC2_HOST 'sudo systemctl status frontline-watcher-${CONTROLLER_ID}'"
echo ""
echo "📋 View logs:"
echo "  ssh $EC2_HOST 'sudo journalctl -u frontline-watcher-${CONTROLLER_ID} -f'"
