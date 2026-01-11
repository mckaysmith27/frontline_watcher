#!/bin/bash

# Interactive EC2 Migration Setup
# This script gathers all needed information and sets up EC2 migration

set -e

echo "🚀 Frontline Watcher - EC2 Migration Setup"
echo "==========================================="
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."
MISSING_DEPS=()

if ! command -v gcloud &> /dev/null; then
    MISSING_DEPS+=("gcloud CLI")
fi

if ! command -v ssh &> /dev/null; then
    MISSING_DEPS+=("ssh")
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "❌ Missing dependencies: ${MISSING_DEPS[*]}"
    echo "   Please install them and try again"
    exit 1
fi

echo "✅ All prerequisites met"
echo ""

# Step 1: Gather EC2 Instance Information
echo "📝 Step 1: EC2 Instance Information"
echo "-----------------------------------"
echo ""

# Check if AWS CLI is available
if command -v aws &> /dev/null; then
    echo "✅ AWS CLI found - we can create the instance for you"
    USE_AWS_CLI=true
else
    echo "⚠️  AWS CLI not found - you'll need to create the instance manually"
    USE_AWS_CLI=false
fi

if [ "$USE_AWS_CLI" = true ]; then
    read -p "Do you already have an EC2 instance? (y/n): " HAS_INSTANCE
    if [ "$HAS_INSTANCE" = "n" ]; then
        echo ""
        echo "We'll create a new EC2 instance. You'll need:"
        echo "  - AWS Access Key ID and Secret Access Key"
        echo "  - Key pair name (or we'll create one)"
        echo "  - Security group ID (or we'll create one)"
        echo ""
        read -p "Continue with instance creation? (y/n): " CREATE_INSTANCE
        if [ "$CREATE_INSTANCE" = "y" ]; then
            read -p "AWS Region (default: us-east-1): " AWS_REGION
            AWS_REGION=${AWS_REGION:-us-east-1}
            read -p "Key pair name: " KEY_NAME
            read -p "Security group ID (or press Enter to create new): " SECURITY_GROUP
            INSTANCE_TYPE="t3.medium"
            
            echo ""
            echo "Creating EC2 instance..."
            if [ -z "$SECURITY_GROUP" ]; then
                # Create security group
                echo "Creating security group..."
                SECURITY_GROUP=$(aws ec2 create-security-group \
                    --group-name frontline-watcher-sg \
                    --description "Frontline Watcher Scraper" \
                    --region $AWS_REGION \
                    --query 'GroupId' --output text)
                echo "Created security group: $SECURITY_GROUP"
                
                # Add SSH rule
                MY_IP=$(curl -s https://checkip.amazonaws.com)
                aws ec2 authorize-security-group-ingress \
                    --group-id $SECURITY_GROUP \
                    --protocol tcp \
                    --port 22 \
                    --cidr $MY_IP/32 \
                    --region $AWS_REGION
                echo "Added SSH access from your IP: $MY_IP"
            fi
            
            # Create instance
            ./create-ec2-instance.sh t3.medium "$KEY_NAME" "$SECURITY_GROUP"
            read -p "Enter the EC2 instance IP or hostname: " EC2_HOST
        else
            read -p "Enter your EC2 instance IP or hostname: " EC2_HOST
        fi
    else
        read -p "Enter your EC2 instance IP or hostname: " EC2_HOST
    fi
else
    echo ""
    echo "Please create an EC2 instance manually:"
    echo "  - Instance type: t3.medium"
    echo "  - OS: Ubuntu 22.04 LTS"
    echo "  - Security group: Allow SSH (port 22) from your IP"
    echo ""
    read -p "Enter your EC2 instance IP or hostname: " EC2_HOST
fi

# Extract username from host if not provided
if [[ "$EC2_HOST" == *"@"* ]]; then
    EC2_USER=$(echo $EC2_HOST | cut -d'@' -f1)
    EC2_HOST_ONLY=$(echo $EC2_HOST | cut -d'@' -f2)
else
    EC2_USER="ubuntu"
    EC2_HOST_ONLY="$EC2_HOST"
fi

echo ""
echo "✅ EC2 Host: $EC2_USER@$EC2_HOST_ONLY"
echo ""

# Step 2: Retrieve or gather credentials
echo "📝 Step 2: Credentials Configuration"
echo "------------------------------------"
echo ""

# Try to get secrets from Google Secret Manager
PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
if [ -n "$PROJECT_ID" ]; then
    echo "Found Google Cloud project: $PROJECT_ID"
    read -p "Retrieve credentials from Google Secret Manager? (y/n): " USE_GCLOUD_SECRETS
    
    if [ "$USE_GCLOUD_SECRETS" = "y" ]; then
        echo ""
        echo "Retrieving secrets from Google Secret Manager..."
        
        # Get secrets
        FRONTLINE_USERNAME=$(gcloud secrets versions access latest --secret="frontline-username" --project=$PROJECT_ID 2>/dev/null || echo "")
        FRONTLINE_PASSWORD=$(gcloud secrets versions access latest --secret="frontline-password" --project=$PROJECT_ID 2>/dev/null || echo "")
        DISTRICT_ID=$(gcloud secrets versions access latest --secret="district-id" --project=$PROJECT_ID 2>/dev/null || echo "")
        FIREBASE_PROJECT_ID=$(gcloud secrets versions access latest --secret="firebase-project-id" --project=$PROJECT_ID 2>/dev/null || echo "sub67-d4648")
        
        if [ -n "$FRONTLINE_USERNAME" ] && [ -n "$FRONTLINE_PASSWORD" ] && [ -n "$DISTRICT_ID" ]; then
            echo "✅ Retrieved credentials from Secret Manager"
        else
            echo "⚠️  Some secrets not found, will prompt for them"
            USE_GCLOUD_SECRETS="n"
        fi
    fi
fi

if [ "$USE_GCLOUD_SECRETS" != "y" ]; then
    read -p "Enter FRONTLINE_USERNAME: " FRONTLINE_USERNAME
    read -sp "Enter FRONTLINE_PASSWORD: " FRONTLINE_PASSWORD
    echo ""
    read -p "Enter DISTRICT_ID: " DISTRICT_ID
    FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID:-"sub67-d4648"}
    read -p "Enter FIREBASE_PROJECT_ID (default: $FIREBASE_PROJECT_ID): " FIREBASE_PROJECT_ID_INPUT
    FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID_INPUT:-$FIREBASE_PROJECT_ID}
fi

# Check for Firebase credentials file
if [ -f "firebase-service-account.json" ]; then
    FIREBASE_CREDENTIALS_PATH="firebase-service-account.json"
    echo "✅ Found Firebase credentials: $FIREBASE_CREDENTIALS_PATH"
else
    read -p "Enter path to Firebase service account JSON: " FIREBASE_CREDENTIALS_PATH
    if [ ! -f "$FIREBASE_CREDENTIALS_PATH" ]; then
        echo "❌ File not found: $FIREBASE_CREDENTIALS_PATH"
        exit 1
    fi
fi

# Optional: NTFY topic
read -p "Enter NTFY topic (optional, press Enter to skip): " NTFY_TOPIC

echo ""
echo "✅ Credentials configured"
echo ""

# Step 3: Number of controllers
echo "📝 Step 3: Controller Configuration"
echo "------------------------------------"
read -p "How many controllers to set up? (1-5, default: 5): " NUM_CONTROLLERS
NUM_CONTROLLERS=${NUM_CONTROLLERS:-5}

if [ "$NUM_CONTROLLERS" -lt 1 ] || [ "$NUM_CONTROLLERS" -gt 5 ]; then
    echo "❌ Invalid number of controllers. Must be 1-5"
    exit 1
fi

echo ""
echo "✅ Will set up $NUM_CONTROLLERS controllers"
echo ""

# Step 4: Test SSH connection
echo "📝 Step 4: Testing SSH Connection"
echo "----------------------------------"
echo "Testing SSH connection to $EC2_USER@$EC2_HOST_ONLY..."
if ssh -o ConnectTimeout=5 -o BatchMode=yes "$EC2_USER@$EC2_HOST_ONLY" "echo 'SSH connection successful'" 2>/dev/null; then
    echo "✅ SSH connection successful"
else
    echo "⚠️  SSH connection test failed or requires password/key"
    echo "   Make sure you can SSH to the instance manually"
    read -p "Continue anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        exit 1
    fi
fi

echo ""

# Step 5: Deploy
echo "🚀 Step 5: Deploying to EC2"
echo "----------------------------"
echo ""
echo "This will:"
echo "  1. Upload setup scripts to EC2"
echo "  2. Run initial setup (Python, Playwright, etc.)"
echo "  3. Upload Firebase credentials"
echo "  4. Create .env files for each controller"
echo "  5. Install systemd services"
echo "  6. Start all services"
echo ""
read -p "Ready to deploy? (y/n): " DEPLOY
if [ "$DEPLOY" != "y" ]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""
echo "📤 Uploading files to EC2..."

# Create temporary directory with all needed files
TEMP_DIR=$(mktemp -d)
cp frontline_watcher_refactored.py "$TEMP_DIR/frontline_watcher_refactored.py"
cp requirements_raw.txt "$TEMP_DIR/"
cp "$FIREBASE_CREDENTIALS_PATH" "$TEMP_DIR/firebase-credentials.json"
cp -r ec2 "$TEMP_DIR/"

# Create deployment package
cd "$TEMP_DIR"
tar czf deploy.tar.gz frontline_watcher_refactored.py requirements_raw.txt firebase-credentials.json ec2/
cd - > /dev/null

# Upload to EC2
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
sudo mv frontline_watcher_refactored.py requirements_raw.txt firebase-credentials.json /opt/frontline-watcher/
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
EOL
    
    if [ -n "$NTFY_TOPIC" ]; then
        echo "NTFY_TOPIC=$NTFY_TOPIC" >> "\$ENV_FILE"
    fi
    
    echo "HOT_WINDOWS=[{\"start\":\"04:30\",\"end\":\"09:30\"},{\"start\":\"11:30\",\"end\":\"23:00\"}]" >> "\$ENV_FILE"
    
    chmod 600 "\$ENV_FILE"
    echo "Created \$ENV_FILE"
done

# Install services (SKIP controller_2)
for i in \$(seq 1 $NUM_CONTROLLERS); do
    # SKIP controller_2 - never install or start it
    if [ "\$i" = "2" ]; then
        echo "⏭️  Skipping controller_2 (disabled)"
        continue
    fi
    sudo ./ec2/install-service.sh controller_\${i}
done

# Start services (SKIP controller_2)
for i in \$(seq 1 $NUM_CONTROLLERS); do
    # SKIP controller_2 - never start it
    if [ "\$i" = "2" ]; then
        continue
    fi
    sudo systemctl start frontline-watcher-controller_\${i}
    sudo systemctl enable frontline-watcher-controller_\${i}
    echo "Started controller_\${i}"
done

# Ensure controller_2 is explicitly disabled (in case it was created)
sudo systemctl stop frontline-watcher-controller_2 2>/dev/null || true
sudo systemctl disable frontline-watcher-controller_2 2>/dev/null || true
echo "✅ Controller_2 explicitly disabled"

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
echo "  4. Verify job events in Firestore:"
echo "     Check Firebase Console -> Firestore -> job_events collection"
echo ""
