#!/bin/bash
# Sync credentials from local .env file to EC2 controller_1
# Usage: ./sync-credentials-to-ec2.sh [ec2-host]

set -e

EC2_HOST="${1:-ubuntu@18.188.47.102}"
APP_DIR="/opt/frontline-watcher"
ENV_FILE="${APP_DIR}/.env.controller_1"
LOCAL_ENV=".env"

echo "🔄 Syncing Credentials from Local .env to EC2"
echo "=============================================="
echo "EC2 Host: $EC2_HOST"
echo "Local .env: $LOCAL_ENV"
echo ""

# Check if local .env exists
if [ ! -f "$LOCAL_ENV" ]; then
    echo "❌ Local .env file not found: $LOCAL_ENV"
    exit 1
fi

# Read credentials from local .env
USERNAME=$(grep "^FRONTLINE_USERNAME=" "$LOCAL_ENV" | cut -d'=' -f2- | tr -d '\r' || echo "")
PASSWORD=$(grep "^FRONTLINE_PASSWORD=" "$LOCAL_ENV" | cut -d'=' -f2- | tr -d '\r' || echo "")
DISTRICT_ID=$(grep "^DISTRICT_ID=" "$LOCAL_ENV" | cut -d'=' -f2- | tr -d '\r' || echo "alpine_school_district")

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "❌ Missing FRONTLINE_USERNAME or FRONTLINE_PASSWORD in local .env file"
    exit 1
fi

echo "📋 Credentials found in local .env:"
echo "   Username: $USERNAME"
echo "   Password: ***HIDDEN***"
echo "   District ID: ${DISTRICT_ID:-alpine_school_district}"
echo ""

# Check if we can connect
if ! ssh -i ~/.ssh/frontline-watcher_V7plus-key.pem "$EC2_HOST" "echo 'Connected'" &>/dev/null; then
    echo "❌ Cannot connect to $EC2_HOST"
    echo "   Make sure you can SSH to the EC2 instance"
    exit 1
fi

echo "📤 Updating credentials on EC2..."

# Update credentials on EC2
ssh -i ~/.ssh/frontline-watcher_V7plus-key.pem "$EC2_HOST" << EOF
    set -e
    APP_DIR="$APP_DIR"
    ENV_FILE="$ENV_FILE"
    
    # Create directory if it doesn't exist
    sudo mkdir -p "\$APP_DIR"
    
    # Backup existing file if it exists
    if [ -f "\$ENV_FILE" ]; then
        sudo cp "\$ENV_FILE" "\$ENV_FILE.backup.\$(date +%Y%m%d_%H%M%S)"
        echo "✅ Backed up existing .env file"
    fi
    
    # Get existing values to preserve
    if [ -f "\$ENV_FILE" ]; then
        EXISTING_CONTROLLER=\$(grep "^CONTROLLER_ID=" "\$ENV_FILE" | cut -d'=' -f2- || echo "controller_1")
        EXISTING_FIREBASE_PROJECT=\$(grep "^FIREBASE_PROJECT_ID=" "\$ENV_FILE" | cut -d'=' -f2- || echo "sub67-d4648")
        EXISTING_FIREBASE_CRED=\$(grep "^FIREBASE_CREDENTIALS_PATH=" "\$ENV_FILE" | cut -d'=' -f2- || echo "/opt/frontline-watcher/firebase-credentials.json")
        EXISTING_NTFY=\$(grep "^NTFY_TOPIC=" "\$ENV_FILE" | cut -d'=' -f2- || echo "frontline-jobs-mckay")
        EXISTING_HOT_WINDOWS=\$(grep "^HOT_WINDOWS=" "\$ENV_FILE" | cut -d'=' -f2- || echo '[{"start":"04:30","end":"09:30"},{"start":"11:30","end":"23:00"}]')
    else
        EXISTING_CONTROLLER="controller_1"
        EXISTING_FIREBASE_PROJECT="sub67-d4648"
        EXISTING_FIREBASE_CRED="/opt/frontline-watcher/firebase-credentials.json"
        EXISTING_NTFY="frontline-jobs-mckay"
        EXISTING_HOT_WINDOWS='[{"start":"04:30","end":"09:30"},{"start":"11:30","end":"23:00"}]'
    fi
    
    # Use DISTRICT_ID from local .env or default
    FINAL_DISTRICT_ID="${DISTRICT_ID:-alpine_school_district}"
    
    # Create new .env file
    sudo tee "\$ENV_FILE" > /dev/null << EOL
CONTROLLER_ID=\$EXISTING_CONTROLLER
DISTRICT_ID=\$FINAL_DISTRICT_ID
FIREBASE_PROJECT_ID=\$EXISTING_FIREBASE_PROJECT
FIREBASE_CREDENTIALS_PATH=\$EXISTING_FIREBASE_CRED
FRONTLINE_USERNAME=$USERNAME
FRONTLINE_PASSWORD=$PASSWORD
NTFY_TOPIC=\$EXISTING_NTFY
HOT_WINDOWS=\$EXISTING_HOT_WINDOWS
EOL
    
    # Set proper permissions
    sudo chmod 600 "\$ENV_FILE"
    sudo chown \$USER:\$USER "\$ENV_FILE"
    
    echo "✅ Updated credentials in \$ENV_FILE"
    echo ""
    echo "New configuration (password hidden):"
    grep -E "^(CONTROLLER_ID|DISTRICT_ID|FRONTLINE_USERNAME|FRONTLINE_PASSWORD|NTFY_TOPIC)" "\$ENV_FILE" | \
        sed 's/FRONTLINE_PASSWORD=.*/FRONTLINE_PASSWORD=***HIDDEN***/'
EOF

echo ""
echo "🔄 Restarting service..."
ssh -i ~/.ssh/frontline-watcher_V7plus-key.pem "$EC2_HOST" "sudo systemctl restart frontline-watcher-controller_1"

echo ""
echo "✅ Credentials synced and service restarted!"
echo ""
echo "📋 Next steps:"
echo "1. Check service status:"
echo "   ssh -i ~/.ssh/frontline-watcher_V7plus-key.pem $EC2_HOST 'sudo systemctl status frontline-watcher-controller_1'"
echo ""
echo "2. Watch logs for login success/failure:"
echo "   ssh -i ~/.ssh/frontline-watcher_V7plus-key.pem $EC2_HOST 'sudo journalctl -u frontline-watcher-controller_1 -f'"
echo ""
echo "3. Look for these success messages:"
echo "   ✅ 'Initial login attempt successful'"
echo "   ✅ 'Verified logged in - not redirected to login page'"
echo "   ✅ 'Frontline watcher started'"
echo ""
echo "4. If you see credential errors, verify the username/password are correct"
echo "   for the controller_1 Frontline account."
