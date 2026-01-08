#!/bin/bash

# Non-interactive setup script - use when you already have EC2 instance
# Usage: ./setup-with-instance.sh <ec2-host> [num-controllers]

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <ec2-host> [num-controllers]"
    echo "Example: $0 ubuntu@ec2-54-123-45-67.compute-1.amazonaws.com 5"
    exit 1
fi

EC2_HOST="$1"
NUM_CONTROLLERS="${2:-5}"

# Extract username and host
if [[ "$EC2_HOST" == *"@"* ]]; then
    EC2_USER=$(echo $EC2_HOST | cut -d'@' -f1)
    EC2_HOST_ONLY=$(echo $EC2_HOST | cut -d'@' -f2)
else
    EC2_USER="ubuntu"
    EC2_HOST_ONLY="$EC2_HOST"
fi

echo "🚀 Frontline Watcher - EC2 Setup"
echo "================================="
echo "EC2 Host: $EC2_USER@$EC2_HOST_ONLY"
echo "Controllers: $NUM_CONTROLLERS"
echo ""

# Try to get credentials from Google Secret Manager
PROJECT_ID="sub67-d4648"
echo "📋 Retrieving credentials from Google Secret Manager..."

FRONTLINE_USERNAME=$(gcloud secrets versions access latest --secret="frontline-username" --project=$PROJECT_ID 2>/dev/null || echo "")
FRONTLINE_PASSWORD=$(gcloud secrets versions access latest --secret="frontline-password" --project=$PROJECT_ID 2>/dev/null || echo "")
DISTRICT_ID=$(gcloud secrets versions access latest --secret="district-id" --project=$PROJECT_ID 2>/dev/null || echo "")
FIREBASE_PROJECT_ID=$(gcloud secrets versions access latest --secret="firebase-project-id" --project=$PROJECT_ID 2>/dev/null || echo "sub67-d4648")

if [ -z "$FRONTLINE_USERNAME" ] || [ -z "$FRONTLINE_PASSWORD" ] || [ -z "$DISTRICT_ID" ]; then
    echo "❌ Could not retrieve all credentials from Secret Manager"
    echo "   Please run the interactive setup or provide credentials manually"
    exit 1
fi

echo "✅ Credentials retrieved from Secret Manager"
echo ""

# Check Firebase credentials file
if [ ! -f "firebase-service-account.json" ]; then
    echo "❌ Firebase credentials file not found: firebase-service-account.json"
    exit 1
fi

echo "✅ Firebase credentials file found"
echo ""

# Test SSH connection
echo "🔌 Testing SSH connection..."
if ssh -o ConnectTimeout=5 -o BatchMode=yes "$EC2_USER@$EC2_HOST_ONLY" "echo 'SSH OK'" 2>/dev/null; then
    echo "✅ SSH connection successful"
else
    echo "⚠️  SSH connection test failed"
    echo "   Make sure you can SSH to the instance manually"
    read -p "Continue anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        exit 1
    fi
fi

echo ""

# Create deployment package
echo "📦 Creating deployment package..."
TEMP_DIR=$(mktemp -d)
cp frontline_watcher_refactored.py "$TEMP_DIR/frontline_watcher.py"
cp requirements_raw.txt "$TEMP_DIR/"
cp firebase-service-account.json "$TEMP_DIR/firebase-credentials.json"
cp -r ec2 "$TEMP_DIR/"

cd "$TEMP_DIR"
tar czf deploy.tar.gz frontline_watcher.py requirements_raw.txt firebase-credentials.json ec2/
cd - > /dev/null

# Upload to EC2
echo "📤 Uploading files to EC2..."
scp "$TEMP_DIR/deploy.tar.gz" "$EC2_USER@$EC2_HOST_ONLY:/tmp/"

echo "✅ Files uploaded"
echo ""

# Run setup on EC2
echo "🔧 Running setup on EC2..."
ssh "$EC2_USER@$EC2_HOST_ONLY" << EOF
set -e

# Extract files
cd /tmp
tar xzf deploy.tar.gz

# Move to application directory
sudo mkdir -p /opt/frontline-watcher
sudo mv frontline_watcher.py requirements_raw.txt firebase-credentials.json /opt/frontline-watcher/
sudo mv ec2 /opt/frontline-watcher/
sudo chown -R \$USER:\$USER /opt/frontline-watcher

# Run setup script
cd /opt/frontline-watcher
chmod +x ec2/*.sh
./ec2/setup-ec2.sh

# Create .env files for each controller
for i in \$(seq 1 $NUM_CONTROLLERS); do
    CONTROLLER_ID="controller_\${i}"
    ENV_FILE="/opt/frontline-watcher/.env.\${CONTROLLER_ID}"
    
    cat > "\$ENV_FILE" << EOL
CONTROLLER_ID=\${CONTROLLER_ID}
DISTRICT_ID=$DISTRICT_ID
FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID
FIREBASE_CREDENTIALS_PATH=/opt/frontline-watcher/firebase-credentials.json
FRONTLINE_USERNAME=$FRONTLINE_USERNAME
FRONTLINE_PASSWORD=$FRONTLINE_PASSWORD
HOT_WINDOWS=[{"start":"04:30","end":"09:30"},{"start":"11:30","end":"23:00"}]
EOL
    
    chmod 600 "\$ENV_FILE"
    echo "Created \$ENV_FILE"
done

# Install services
for i in \$(seq 1 $NUM_CONTROLLERS); do
    sudo ./ec2/install-service.sh controller_\${i}
done

# Start services
for i in \$(seq 1 $NUM_CONTROLLERS); do
    sudo systemctl start frontline-watcher-controller_\${i}
    sudo systemctl enable frontline-watcher-controller_\${i}
    echo "Started controller_\${i}"
done

# Cleanup
rm -rf /tmp/deploy.tar.gz /tmp/ec2

echo ""
echo "✅ Setup complete!"
EOF

# Cleanup local temp files
rm -rf "$TEMP_DIR"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Next steps:"
echo "  1. Check service status:"
echo "     ssh $EC2_USER@$EC2_HOST_ONLY 'sudo systemctl status frontline-watcher-controller_1'"
echo ""
echo "  2. View logs:"
echo "     ssh $EC2_USER@$EC2_HOST_ONLY 'sudo journalctl -u frontline-watcher-controller_1 -f'"
echo ""
echo "  3. Monitor all services:"
echo "     ssh $EC2_USER@$EC2_HOST_ONLY 'cd /opt/frontline-watcher && ./ec2/monitor-services.sh status'"
echo ""
