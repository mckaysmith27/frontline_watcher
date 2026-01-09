#!/bin/bash

# Quick deploy script to update EC2 with latest code
# Usage: ./deploy-fix.sh

set -e

EC2_HOST="sub67-watcher"

echo "🚀 Deploying login fix to EC2"
echo "=============================="
echo ""

# Upload file
echo "📤 Uploading updated code..."
scp frontline_watcher_refactored.py ${EC2_HOST}:/tmp/frontline_watcher.py

# Deploy on EC2
echo "🔧 Deploying on EC2..."
ssh ${EC2_HOST} << 'EOF'
set -e

# Copy to app directory
sudo cp /tmp/frontline_watcher.py /opt/frontline-watcher/frontline_watcher.py
sudo chown ubuntu:ubuntu /opt/frontline-watcher/frontline_watcher.py

# Restart services
echo "🔄 Restarting services..."
sudo systemctl restart frontline-watcher-controller_1
sudo systemctl restart frontline-watcher-controller_2

echo "✅ Deployment complete!"
echo ""
echo "📋 Service status:"
for i in {1..2}; do
    STATUS=$(sudo systemctl is-active frontline-watcher-controller_${i} 2>/dev/null || echo "inactive")
    echo "  Controller $i: $STATUS"
done
EOF

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 View logs:"
echo "  ./view-ec2-logs.sh 1 follow"
echo "  ./view-ec2-logs.sh 2 follow"
