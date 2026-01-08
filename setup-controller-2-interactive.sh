#!/bin/bash
# Interactive setup for Controller 2 credentials
# This script will prompt for username and password

set -e

echo "🔐 Setting up Controller 2 Credentials"
echo "========================================"
echo ""
read -p "Enter username for Controller 2: " USERNAME2
read -sp "Enter password for Controller 2: " PASSWORD2
echo ""

if [ -z "$USERNAME2" ] || [ -z "$PASSWORD2" ]; then
    echo "❌ Error: Username and password are required"
    exit 1
fi

echo ""
echo "Setting up credentials..."
./setup-controller-credentials.sh 2 "$USERNAME2" "$PASSWORD2"

echo ""
echo "✅ Controller 2 credentials set up!"
echo ""
echo "Next steps:"
echo "  1. Update jobs: ./setup-scrapers-configurable.sh"
echo "  2. Set up schedulers: ./setup-scheduler-configurable.sh"
echo "  3. Start scraping: ./control-scrapers.sh start"

