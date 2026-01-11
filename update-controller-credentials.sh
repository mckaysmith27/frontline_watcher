#!/bin/bash
# Update controller_1 credentials on EC2
# Usage: ./update-controller-credentials.sh [ec2-host]

set -e

EC2_HOST="${1:-sub67-watcher}"
APP_DIR="/opt/frontline-watcher"
ENV_FILE="${APP_DIR}/.env.controller_1"

echo "🔐 Update Controller 1 Credentials"
echo "==================================="
echo "EC2 Host: $EC2_HOST"
echo ""
echo "⚠️  IMPORTANT: Make sure you have the CORRECT username and password"
echo "   for the controller_1 Frontline account."
echo ""
echo "   If credentials are wrong, you'll see SSO/Captcha errors even though"
echo "   the real issue is incorrect username/password."
echo ""

# Get credentials
read -p "Enter FRONTLINE_USERNAME for controller_1: " USERNAME
read -sp "Enter FRONTLINE_PASSWORD for controller_1: " PASSWORD
echo ""

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "❌ Username and password are required"
    exit 1
fi

# Get district ID (optional - will keep existing if not provided)
echo ""
read -p "Enter DISTRICT_ID (press Enter to keep existing): " DISTRICT_ID

# Check if we can connect
if ! ssh "$EC2_HOST" "echo 'Connected'" &>/dev/null; then
    echo "❌ Cannot connect to $EC2_HOST"
    echo "   Make sure you can SSH to the EC2 instance"
    exit 1
fi

echo ""
echo "📤 Updating credentials on EC2..."

# Update credentials on EC2
ssh "$EC2_HOST" << EOF
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
    
    # Get existing DISTRICT_ID if not provided
    if [ -z "$DISTRICT_ID" ] && [ -f "\$ENV_FILE" ]; then
        EXISTING_DISTRICT=\$(grep "^DISTRICT_ID=" "\$ENV_FILE" | cut -d'=' -f2- || echo "")
        if [ -n "\$EXISTING_DISTRICT" ]; then
            DISTRICT_ID="\$EXISTING_DISTRICT"
            echo "   Using existing DISTRICT_ID: \$DISTRICT_ID"
        fi
    fi
    
    # Get other existing values
    if [ -f "\$ENV_FILE" ]; then
        EXISTING_CONTROLLER=\$(grep "^CONTROLLER_ID=" "\$ENV_FILE" | cut -d'=' -f2- || echo "controller_1")
        EXISTING_FIREBASE_PROJECT=\$(grep "^FIREBASE_PROJECT_ID=" "\$ENV_FILE" | cut -d'=' -f2- || echo "sub67-d4648")
        EXISTING_FIREBASE_CRED=\$(grep "^FIREBASE_CREDENTIALS_PATH=" "\$ENV_FILE" | cut -d'=' -f2- || echo "/opt/frontline-watcher/firebase-credentials.json")
        EXISTING_NTFY=\$(grep "^NTFY_TOPIC=" "\$ENV_FILE" | cut -d'=' -f2- || echo "")
        EXISTING_HOT_WINDOWS=\$(grep "^HOT_WINDOWS=" "\$ENV_FILE" | cut -d'=' -f2- || echo '[{"start":"04:30","end":"09:30"},{"start":"11:30","end":"23:00"}]')
    else
        EXISTING_CONTROLLER="controller_1"
        EXISTING_FIREBASE_PROJECT="sub67-d4648"
        EXISTING_FIREBASE_CRED="/opt/frontline-watcher/firebase-credentials.json"
        EXISTING_NTFY=""
        EXISTING_HOT_WINDOWS='[{"start":"04:30","end":"09:30"},{"start":"11:30","end":"23:00"}]'
    fi
    
    # Use provided DISTRICT_ID or existing
    FINAL_DISTRICT_ID="${DISTRICT_ID:-alpine_school_district}"
    if [ -z "$DISTRICT_ID" ] && [ -n "\$EXISTING_DISTRICT" ]; then
        FINAL_DISTRICT_ID="\$EXISTING_DISTRICT"
    fi
    
    # Create new .env file
    sudo tee "\$ENV_FILE" > /dev/null << EOL
CONTROLLER_ID=\$EXISTING_CONTROLLER
DISTRICT_ID=\$FINAL_DISTRICT_ID
FIREBASE_PROJECT_ID=\$EXISTING_FIREBASE_PROJECT
FIREBASE_CREDENTIALS_PATH=\$EXISTING_FIREBASE_CRED
FRONTLINE_USERNAME=$USERNAME
FRONTLINE_PASSWORD=$PASSWORD
EOL
    
    # Add optional NTFY topic if it existed
    if [ -n "\$EXISTING_NTFY" ]; then
        echo "NTFY_TOPIC=\$EXISTING_NTFY" | sudo tee -a "\$ENV_FILE" > /dev/null
    fi
    
    # Add hot windows
    echo "HOT_WINDOWS=\$EXISTING_HOT_WINDOWS" | sudo tee -a "\$ENV_FILE" > /dev/null
    
    # Set proper permissions
    sudo chmod 600 "\$ENV_FILE"
    sudo chown \$USER:\$USER "\$ENV_FILE"
    
    echo "✅ Updated credentials in \$ENV_FILE"
    echo ""
    echo "New configuration (password hidden):"
    grep -E "^(CONTROLLER_ID|DISTRICT_ID|FRONTLINE_USERNAME|FRONTLINE_PASSWORD)" "\$ENV_FILE" | \
        sed 's/FRONTLINE_PASSWORD=.*/FRONTLINE_PASSWORD=***HIDDEN***/'
EOF

echo ""
echo "🔄 Restarting service..."
ssh "$EC2_HOST" "sudo systemctl restart frontline-watcher-controller_1"

echo ""
echo "✅ Credentials updated and service restarted!"
echo ""
echo "📋 Next steps:"
echo "1. Check service status:"
echo "   ssh $EC2_HOST 'sudo systemctl status frontline-watcher-controller_1'"
echo ""
echo "2. Watch logs for login success/failure:"
echo "   ssh $EC2_HOST 'sudo journalctl -u frontline-watcher-controller_1 -f'"
echo ""
echo "3. Look for these success messages:"
echo "   ✅ 'Initial login attempt successful'"
echo "   ✅ 'Verified logged in - not redirected to login page'"
echo "   ✅ 'Frontline watcher started'"
echo ""
echo "4. If you see SSO/Captcha errors, the credentials might still be wrong,"
echo "   or Frontline may be blocking automated logins."
