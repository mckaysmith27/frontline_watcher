#!/bin/bash

# Install the auto-disable mechanism for controller_2 on EC2
# This can be run remotely via SSH to ensure controller_2 never starts

set -e

EC2_HOST="${1:-sub67-watcher}"

echo "🔧 Installing Controller 2 Auto-Disable on EC2"
echo "=============================================="
echo ""

# Upload the script
echo "📤 Uploading disable script..."
scp ec2/disable-controller-2-on-boot.sh ${EC2_HOST}:/tmp/disable-controller-2-on-boot.sh

# Run it on EC2
echo "🔧 Installing on EC2..."
ssh ${EC2_HOST} << 'EOF'
set -e
chmod +x /tmp/disable-controller-2-on-boot.sh
sudo /tmp/disable-controller-2-on-boot.sh
EOF

echo ""
echo "✅ Controller 2 auto-disable installed!"
echo ""
echo "📋 Verification:"
ssh ${EC2_HOST} 'sudo systemctl is-enabled disable-controller-2' && echo "  ✅ Auto-disable service is enabled"
ssh ${EC2_HOST} 'sudo systemctl is-enabled frontline-watcher-controller_2' 2>/dev/null && echo "  ⚠️  Controller 2 is still enabled" || echo "  ✅ Controller 2 is disabled"

echo ""
echo "✅ Controller_2 will NOT start on boot"
echo "   The auto-disable service runs on every boot to ensure this"
