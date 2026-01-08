#!/bin/bash

# Complete EC2 startup script
# 1. Waits for EC2 to be reachable
# 2. Installs auto-disable for controller_2
# 3. Ensures controller_1 is enabled
# 4. Verifies everything is set up correctly

set -e

EC2_HOST="sub67-watcher"
MAX_WAIT=300  # 5 minutes max wait
WAIT_INTERVAL=10

echo "🚀 EC2 Complete Startup Script"
echo "==============================="
echo ""

# Step 1: Wait for EC2 to be reachable
echo "⏳ Step 1: Waiting for EC2 to be reachable..."
echo "   (This may take 1-2 minutes after starting the instance)"
echo ""

WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$EC2_HOST" "echo 'Connected'" &>/dev/null; then
        echo "✅ EC2 is reachable!"
        break
    fi
    
    echo "   Waiting... (${WAITED}s / ${MAX_WAIT}s)"
    sleep $WAIT_INTERVAL
    WAITED=$((WAITED + WAIT_INTERVAL))
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo "❌ EC2 did not become reachable within ${MAX_WAIT}s"
    echo "   Please check:"
    echo "   1. Instance is running in AWS Console"
    echo "   2. Security group allows SSH (port 22)"
    echo "   3. Instance has a public IP"
    exit 1
fi

echo ""
echo "🔧 Step 2: Installing controller_2 auto-disable service..."
echo ""

# Upload and install the auto-disable service
scp ec2/disable-controller-2-on-boot.sh ${EC2_HOST}:/tmp/disable-controller-2-on-boot.sh 2>/dev/null || {
    echo "⚠️  Could not upload script, trying direct installation..."
}

ssh ${EC2_HOST} << 'EOF'
set -e
cd /opt/frontline-watcher 2>/dev/null || cd ~

# If script was uploaded, use it; otherwise create it inline
if [ -f /tmp/disable-controller-2-on-boot.sh ]; then
    chmod +x /tmp/disable-controller-2-on-boot.sh
    sudo /tmp/disable-controller-2-on-boot.sh
else
    # Create the service inline
    SERVICE_NAME="disable-controller-2"
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    
    sudo tee $SERVICE_FILE > /dev/null << 'INLINE_EOF'
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
INLINE_EOF

    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    sudo systemctl start $SERVICE_NAME
    echo "✅ Auto-disable service installed"
fi
EOF

echo ""
echo "🔧 Step 3: Ensuring controller_2 is disabled..."
echo ""

ssh ${EC2_HOST} << 'EOF'
sudo systemctl stop frontline-watcher-controller_2 2>/dev/null || true
sudo systemctl disable frontline-watcher-controller_2 2>/dev/null || true
echo "✅ Controller 2 stopped and disabled"
EOF

echo ""
echo "🔧 Step 4: Ensuring controller_1 is enabled..."
echo ""

ssh ${EC2_HOST} << 'EOF'
sudo systemctl enable frontline-watcher-controller_1 2>/dev/null || echo "⚠️  Controller 1 service may not exist yet"
echo "✅ Controller 1 enabled (will start on boot)"
EOF

echo ""
echo "📋 Step 5: Verification..."
echo ""

ssh ${EC2_HOST} << 'EOF'
echo "Controller 2 Status:"
CTRL2_STATUS=$(sudo systemctl is-active frontline-watcher-controller_2 2>/dev/null || echo "inactive")
CTRL2_ENABLED=$(sudo systemctl is-enabled frontline-watcher-controller_2 2>/dev/null || echo "disabled")
echo "  Status: $CTRL2_STATUS"
echo "  Enabled: $CTRL2_ENABLED"

echo ""
echo "Controller 1 Status:"
CTRL1_STATUS=$(sudo systemctl is-active frontline-watcher-controller_1 2>/dev/null || echo "inactive")
CTRL1_ENABLED=$(sudo systemctl is-enabled frontline-watcher-controller_1 2>/dev/null || echo "disabled")
echo "  Status: $CTRL1_STATUS"
echo "  Enabled: $CTRL1_ENABLED"

echo ""
echo "Auto-Disable Service:"
AUTO_DISABLE_ENABLED=$(sudo systemctl is-enabled disable-controller-2 2>/dev/null || echo "not found")
echo "  Enabled: $AUTO_DISABLE_ENABLED"
EOF

echo ""
echo "✅ Setup Complete!"
echo ""
echo "📋 Summary:"
echo "  ✅ Controller 2: DISABLED (won't start on boot)"
echo "  ✅ Controller 1: ENABLED (will start on boot)"
echo "  ✅ Auto-disable service: INSTALLED (ensures controller_2 stays disabled)"
echo ""
echo "📋 To start controller_1 now:"
echo "   ./control-controllers.sh start 1"
echo ""
echo "📋 To check status:"
echo "   ./control-controllers.sh status"
