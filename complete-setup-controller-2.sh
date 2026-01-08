#!/bin/bash
# Complete setup for Controller 2 and enable automatic scraping
# Usage: ./complete-setup-controller-2.sh <username> <password>

set -e

PROJECT_ID="sub67-d4648"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <username> <password>"
    echo ""
    echo "Example:"
    echo "  $0 controller2user mypassword123"
    exit 1
fi

USERNAME2="$1"
PASSWORD2="$2"

echo "🚀 Complete Setup: Controller 2 + Auto Scraping"
echo "================================================"
echo ""
echo "Configuration:"
echo "  - 2 scrapers"
echo "  - 16-second intervals per scraper"
echo "  - ~8 seconds combined frequency"
echo "  - Active: 6 AM - 8 PM Mountain Time"
echo ""

# Step 1: Set up Controller 2 credentials
echo "Step 1: Setting up Controller 2 credentials..."
echo "=============================================="
./setup-controller-credentials.sh 2 "$USERNAME2" "$PASSWORD2"

# Step 2: Update jobs
echo ""
echo "Step 2: Updating Cloud Run Jobs..."
echo "==================================="
./setup-scrapers-configurable.sh

# Step 3: Set up schedulers
echo ""
echo "Step 3: Setting up Cloud Scheduler..."
echo "======================================"
./setup-scheduler-configurable.sh

# Step 4: Enable automatic scraping
echo ""
echo "Step 4: Enabling automatic scraping..."
echo "======================================="
./control-scrapers.sh start

echo ""
echo "✅ Setup Complete!"
echo ""
echo "📊 Status:"
./control-scrapers.sh status
echo ""
echo "Your scrapers are now running automatically!"
echo "  - Controller 1: Every 16 seconds (offset: 0s)"
echo "  - Controller 2: Every 16 seconds (offset: 8s)"
echo "  - Combined: Site scraped every ~8 seconds"
echo ""
echo "To control:"
echo "  ./control-scrapers.sh stop   # Pause scraping"
echo "  ./control-scrapers.sh start   # Resume scraping"
echo "  ./control-scrapers.sh status  # Check status"

