#!/bin/bash

# Quick deployment script - uploads code and restarts services
# Usage: ./quick-deploy.sh <ec2-host> [controller-id]
# If controller-id omitted, updates all controllers

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <ec2-host> [controller-id]"
    echo "Example: $0 ubuntu@ec2-54-123-45-67.compute-1.amazonaws.com controller_1"
    echo "        $0 ubuntu@ec2-54-123-45-67.compute-1.amazonaws.com  # All controllers"
    exit 1
fi

EC2_HOST="$1"
CONTROLLER_ID="$2"
APP_DIR="/opt/frontline-watcher"

echo "🚀 Quick Deploy to EC2"
echo "Host: $EC2_HOST"
if [ -n "$CONTROLLER_ID" ]; then
    echo "Controller: $CONTROLLER_ID"
    CONTROLLERS=("$CONTROLLER_ID")
else
    echo "Controllers: All (1-5)"
    CONTROLLERS=("controller_1" "controller_2" "controller_3" "controller_4" "controller_5")
fi
echo ""

# Create deployment package
TEMP_DIR=$(mktemp -d)
echo "📦 Creating deployment package..."
cp frontline_watcher_refactored.py "$TEMP_DIR/frontline_watcher.py"
cp requirements_raw.txt "$TEMP_DIR/"

cd "$TEMP_DIR"
tar czf deploy.tar.gz frontline_watcher.py requirements_raw.txt
cd - > /dev/null

# Upload and deploy
echo "📤 Uploading to EC2..."
scp "$TEMP_DIR/deploy.tar.gz" "$EC2_HOST:/tmp/"

echo "🔧 Deploying on EC2..."
ssh "$EC2_HOST" << EOF
set -e

# Extract files
cd $APP_DIR
tar xzf /tmp/deploy.tar.gz
chown \$USER:\$USER frontline_watcher.py requirements_raw.txt

# Update virtual environment
source $APP_DIR/venv/bin/activate
pip install -q -r requirements_raw.txt

# Restart affected services
EOF

for CONTROLLER in "${CONTROLLERS[@]}"; do
    ssh "$EC2_HOST" "sudo systemctl restart frontline-watcher-${CONTROLLER} 2>/dev/null || echo 'Service ${CONTROLLER} not found or not running'"
done

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Verify services:"
echo "  ssh $EC2_HOST 'sudo systemctl status frontline-watcher-controller_1'"
