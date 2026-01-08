#!/bin/bash
# Quick setup script for 2 scrapers with 16-second intervals
# This is a convenience script that does everything in one go

set -e

PROJECT_ID="sub67-d4648"

echo "🚀 Quick Setup: 2 Scrapers, 16-Second Intervals"
echo "================================================"
echo ""

# Step 1: Set up Controller 2 credentials
echo "Step 1: Set up Controller 2 Credentials"
echo "========================================"
echo ""
read -p "Enter username for Controller 2: " USERNAME2
read -sp "Enter password for Controller 2: " PASSWORD2
echo ""

if [ -z "$USERNAME2" ] || [ -z "$PASSWORD2" ]; then
    echo "❌ Error: Username and password required"
    exit 1
fi

echo "Setting up credentials..."
./setup-controller-credentials.sh 2 "$USERNAME2" "$PASSWORD2"

echo ""
echo "Step 2: Create/Update Cloud Run Jobs"
echo "======================================"
echo ""
./setup-scrapers-configurable.sh

echo ""
echo "Step 3: Set up Cloud Scheduler"
echo "==============================="
echo ""
./setup-scheduler-configurable.sh

echo ""
echo "Step 4: Enable Automatic Scraping"
echo "=================================="
echo ""
./control-scrapers.sh start

echo ""
echo "✅ Setup Complete!"
echo ""
echo "Configuration:"
echo "  - 2 scrapers"
echo "  - Each scraper runs every 16 seconds"
echo "  - Combined frequency: ~8 seconds between scrapes"
echo "  - Active time: 6 AM - 8 PM Mountain Time"
echo ""
echo "To check status: ./control-scrapers.sh status"
echo "To stop: ./control-scrapers.sh stop"
echo "To start: ./control-scrapers.sh start"

