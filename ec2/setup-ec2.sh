#!/bin/bash

# EC2 Setup Script for Frontline Watcher Scrapers
# Run this on a fresh t3.medium EC2 instance (Ubuntu 22.04 LTS)

set -e

echo "🚀 Setting up Frontline Watcher on EC2"
echo "========================================"
echo ""

# Update system
echo "📦 Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

# Install Python 3.10+ and pip
echo "🐍 Installing Python..."
sudo apt-get install -y python3 python3-pip python3-venv

# Install system dependencies for Playwright
echo "📚 Installing system dependencies..."
sudo apt-get install -y \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libcairo2 \
    libatspi2.0-0 \
    libxshmfence1

# Create application directory
echo "📁 Creating application directory..."
APP_DIR="/opt/frontline-watcher"
sudo mkdir -p $APP_DIR
sudo chown $USER:$USER $APP_DIR

# Copy application files (if not already present from deployment)
echo "📋 Copying application files..."
if [ -f "frontline_watcher_refactored.py" ]; then
    cp frontline_watcher_refactored.py $APP_DIR/frontline_watcher_refactored.py
    cp requirements_raw.txt $APP_DIR/
elif [ -f "$APP_DIR/frontline_watcher_refactored.py" ]; then
    echo "  Files already present, skipping copy"
else
    echo "  ⚠️  Warning: Application files not found. They should be deployed separately."
fi

# Create virtual environment
echo "🔧 Setting up Python virtual environment..."
cd $APP_DIR
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo "📥 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements_raw.txt

# Install Playwright browsers
echo "🌐 Installing Playwright browsers..."
playwright install chromium
playwright install-deps chromium

# Create logs directory
echo "📝 Creating logs directory..."
sudo mkdir -p /var/log/frontline-watcher
sudo chown $USER:$USER /var/log/frontline-watcher

# Create .env file template
echo "⚙️  Creating .env template..."
cat > $APP_DIR/.env.template << 'EOF'
# Frontline Watcher Configuration
CONTROLLER_ID=controller_1
DISTRICT_ID=your_district_id
FIREBASE_PROJECT_ID=sub67-d4648
FIREBASE_CREDENTIALS_PATH=/opt/frontline-watcher/firebase-credentials.json
FRONTLINE_USERNAME=your_username
FRONTLINE_PASSWORD=your_password

# Optional: NTFY notifications
NTFY_TOPIC=your_ntfy_topic

# Optional: Scraper configuration
NUM_SCRAPERS=5
SCRAPE_INTERVAL_SECONDS=15
HOT_WINDOWS=[{"start":"04:30","end":"09:30"},{"start":"11:30","end":"23:00"}]
EOF

echo ""
echo "✅ EC2 setup complete!"
echo ""
echo "⚠️  IMPORTANT: Controller_2 is DISABLED"
echo "   - Controller_2 will NOT be installed or started"
echo "   - Only controller_1 should be used"
echo "   - This prevents rate limiting issues"
echo ""
echo "📋 Next steps:"
echo "1. Copy firebase-credentials.json to $APP_DIR/"
echo "2. Create .env file from template: cp $APP_DIR/.env.template $APP_DIR/.env.controller_1"
echo "3. Edit .env.controller_1 with your actual credentials"
echo "4. Run: sudo ./install-service.sh controller_1 to set up systemd service"
echo "5. Start service: sudo systemctl start frontline-watcher-controller_1"
echo ""
echo "⚠️  DO NOT install controller_2 - it is permanently disabled"
